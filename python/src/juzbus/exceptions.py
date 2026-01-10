"""Exception classes for juzbus."""


class JuzbusError(Exception):
    """Base exception for juzbus errors."""
    pass


class ConnectionError(JuzbusError):
    """Failed to connect to directory or instance."""
    pass


class TimeoutError(JuzbusError):
    """Operation timed out."""
    pass


class InstanceNotFoundError(JuzbusError):
    """Requested instance not found."""
    pass


class RegistrationError(JuzbusError):
    """Failed to register service instance."""
    pass
