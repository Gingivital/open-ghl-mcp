"""
Smoke test: validates PIT auth config loads and token flows without network calls.
Run with: uv run pytest tests/test_pit_config.py -v
"""
import pytest


class TestPITConfig:
    """Verify .env PIT config is wired end-to-end"""

    def test_env_loads_pit_mode(self):
        from src.services.oauth import OAuthService, AuthMode

        svc = OAuthService()
        assert svc.settings.auth_mode == AuthMode.PIT, (
            f"Expected PIT mode, got {svc.settings.auth_mode}. "
            "Check that AUTH_MODE=pit is in your .env"
        )

    def test_pit_token_present(self):
        from src.services.oauth import OAuthService

        svc = OAuthService()
        tok = svc.settings.ghl_pit_token
        assert tok and tok.startswith("pit-"), (
            f"GHL_PIT_TOKEN missing or malformed: {tok!r}"
        )
        print(f"\n  Token: {tok[:12]}...{tok[-4:]}")

    def test_location_id_set(self):
        from src.services.oauth import OAuthService

        svc = OAuthService()
        loc = svc.settings.ghl_location_id
        assert loc, (
            "GHL_LOCATION_ID is not set in .env. "
            "Add it so API calls can include ?locationId=..."
        )
        print(f"\n  Location ID: {loc}")

    @pytest.mark.asyncio
    async def test_get_valid_token_no_network(self):
        from src.services.oauth import OAuthService

        svc = OAuthService()
        token = await svc.get_valid_token()
        assert token.startswith("pit-")

    @pytest.mark.asyncio
    async def test_get_location_token_no_network(self):
        from src.services.oauth import OAuthService

        svc = OAuthService()
        loc_id = svc.settings.ghl_location_id or "placeholder"
        token = await svc.get_location_token(loc_id)
        assert token.startswith("pit-")

    def test_standard_auth_not_initialised(self):
        """In PIT mode the Supabase standard-auth service must stay None"""
        from src.services.oauth import OAuthService

        svc = OAuthService()
        assert svc._standard_auth is None
