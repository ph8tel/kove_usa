defmodule Kove.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  # Reserved handles that cannot be claimed by riders
  @reserved_handles ~w(home bikes users settings auth admin privacy support
    help about contact api riders r www)

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :google_id, :string
    field :handle, :string
    field :handle_locked, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Kove.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for registration via Google OAuth.

  Sets email, google_id, and auto-confirms the account since Google has
  already verified the email address.
  """
  def google_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :google_id])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Kove.Repo)
    |> unique_constraint(:email)
    |> unique_constraint(:google_id)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Kove.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  A changeset for updating the rider handle.

  Validates format (lowercase alphanumeric + underscores, 3–30 chars),
  uniqueness, and that the handle is not reserved.

  ## Options

    * `:validate_unique` - Set to false during live validation. Defaults to `true`.
  """
  def handle_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:handle])
    |> validate_required([:handle])
    |> validate_format(:handle, ~r/^[a-z0-9_]+$/,
      message: "only lowercase letters, numbers, and underscores"
    )
    |> validate_length(:handle, min: 3, max: 30)
    |> validate_handle_not_reserved()
    |> then(fn cs ->
      if Keyword.get(opts, :validate_unique, true) do
        cs
        |> unsafe_validate_unique(:handle, Kove.Repo)
        |> unique_constraint(:handle)
      else
        cs
      end
    end)
  end

  defp validate_handle_not_reserved(changeset) do
    case get_change(changeset, :handle) do
      nil ->
        changeset

      handle ->
        if handle in @reserved_handles do
          add_error(changeset, :handle, "is reserved")
        else
          changeset
        end
    end
  end

  @doc """
  Derives a candidate handle from an email address.

  Takes the local part of the email, lowercases it, replaces non-alphanumeric
  characters with underscores, collapses consecutive underscores, strips leading
  and trailing underscores, and truncates to 20 characters.
  """
  def handle_from_email(email) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first("")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
    |> String.slice(0, 20)
  end
end
