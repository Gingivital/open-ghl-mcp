"""Unit tests for PIT (Private Integration Token) authentication mode"""

import pytest
from unittest.mock import patch
import os


class TestPITAuthMode:
    """Test PIT auth mode in OAuthService"""

    def test_authmode_has_pit(self):
        from src.services.oauth import AuthMode

        assert AuthMode.PIT == "pit"
        assert AuthMode.STANDARD == "standard"
        assert AuthMode.CUSTOM == "custom"

    def test_settings_pit_fields_exist(self):
        from src.services.oauth import OAuthSettings

        # OAuthSettings should have ghl_pit_token and ghl_location_id
        fields = OAuthSettings.model_fields
        assert "ghl_pit_token" in fields
        assert "ghl_location_id" in fields

    def test_settings_pit_mode_validation_requires_token(self):
        from src.services.oauth import OAuthSettings

        # Patch load_dotenv so the .env file doesn't re-inject GHL_PIT_TOKEN,
        # then strip the key from os.environ to simulate a clean PIT-mode env.
        with patch("dotenv.load_dotenv"):
            with patch.dict(os.environ, {"AUTH_MODE": "pit"}, clear=False):
                os.environ.pop("GHL_PIT_TOKEN", None)
                with pytest.raises(ValueError, match="GHL_PIT_TOKEN"):
                    OAuthSettings()

    def test_settings_pit_mode_valid_with_token(self):
        from src.services.oauth import OAuthSettings, AuthMode

        with patch.dict(
            os.environ,
            {
                "AUTH_MODE": "pit",
                "GHL_PIT_TOKEN": "pit-test-token-abc",
            },
            clear=False,
        ):
            settings = OAuthSettings()
            assert settings.auth_mode == AuthMode.PIT
            assert settings.ghl_pit_token == "pit-test-token-abc"

    @pytest.mark.asyncio
    async def test_get_valid_token_returns_pit(self):
        from src.services.oauth import OAuthService, AuthMode

        with patch.dict(
            os.environ,
            {
                "AUTH_MODE": "pit",
                "GHL_PIT_TOKEN": "pit-abc-123",
            },
            clear=False,
        ):
            service = OAuthService()
            assert service.settings.auth_mode == AuthMode.PIT
            token = await service.get_valid_token()
            assert token == "pit-abc-123"

    @pytest.mark.asyncio
    async def test_get_location_token_returns_pit(self):
        from src.services.oauth import OAuthService

        with patch.dict(
            os.environ,
            {
                "AUTH_MODE": "pit",
                "GHL_PIT_TOKEN": "pit-abc-123",
            },
            clear=False,
        ):
            service = OAuthService()
            # Location token should return the PIT directly — no OAuth exchange
            token = await service.get_location_token("some-location-id")
            assert token == "pit-abc-123"

    @pytest.mark.asyncio
    async def test_load_token_returns_none_in_pit_mode(self):
        from src.services.oauth import OAuthService

        with patch.dict(
            os.environ,
            {
                "AUTH_MODE": "pit",
                "GHL_PIT_TOKEN": "pit-abc-123",
            },
            clear=False,
        ):
            service = OAuthService()
            result = await service.load_token()
            assert result is None

    @pytest.mark.asyncio
    async def test_save_token_noop_in_pit_mode(self, tmp_path):
        from src.services.oauth import OAuthService
        from src.models.auth import StoredToken
        from datetime import datetime, timedelta

        with patch.dict(
            os.environ,
            {
                "AUTH_MODE": "pit",
                "GHL_PIT_TOKEN": "pit-abc-123",
            },
            clear=False,
        ):
            service = OAuthService()
            token = StoredToken(
                access_token="test",
                refresh_token="refresh",
                token_type="Bearer",
                expires_at=datetime.now() + timedelta(hours=1),
                scope="contacts.readonly",
                user_type="Location",
            )
            # Should not raise and should not write any file
            await service.save_token(token)
            assert not (tmp_path / "tokens.json").exists()

    def test_pit_mode_init_does_not_force_custom(self):
        """PIT mode should survive OAuthService.__init__ without being overridden"""
        from src.services.oauth import OAuthService, AuthMode

        with patch.dict(
            os.environ,
            {
                "AUTH_MODE": "pit",
                "GHL_PIT_TOKEN": "pit-survives-init",
            },
            clear=False,
        ):
            service = OAuthService()
            assert service.settings.auth_mode == AuthMode.PIT
            assert service._standard_auth is None


class TestSetupPITDetection:
    """Test that setup.py correctly detects and handles PIT mode"""

    def test_check_auth_status_detects_pit(self, tmp_path):
        from src.services.setup import StandardModeSetup

        setup = StandardModeSetup.__new__(StandardModeSetup)
        setup.config_dir = tmp_path / "config"
        setup.env_file = tmp_path / ".env"
        setup.env_file.write_text("AUTH_MODE=pit\nGHL_PIT_TOKEN=pit-abc-123\n")

        valid, msg = setup.check_auth_status()
        assert valid is True
        assert "PIT" in msg

    def test_check_auth_status_detects_custom(self, tmp_path):
        from src.services.setup import StandardModeSetup

        setup = StandardModeSetup.__new__(StandardModeSetup)
        setup.config_dir = tmp_path / "config"
        setup.env_file = tmp_path / ".env"
        setup.env_file.write_text(
            "AUTH_MODE=custom\nGHL_CLIENT_ID=abc\nGHL_CLIENT_SECRET=xyz\n"
        )

        valid, msg = setup.check_auth_status()
        assert valid is True
        assert "Custom" in msg

    @pytest.mark.asyncio
    async def test_validate_existing_config_pit_no_network(self, tmp_path):
        from src.services.setup import StandardModeSetup
        import httpx

        setup = StandardModeSetup.__new__(StandardModeSetup)
        setup.config_dir = tmp_path / "config"
        setup.env_file = tmp_path / ".env"
        setup.client = httpx.AsyncClient()
        setup.env_file.write_text("AUTH_MODE=pit\nGHL_PIT_TOKEN=pit-abc-123\n")

        # Should return True without making any network calls
        result = await setup.validate_existing_config()
        assert result is True
        await setup.client.aclose()
