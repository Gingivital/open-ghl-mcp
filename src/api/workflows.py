"""Workflows and contact notes client for GoHighLevel API v2"""

from typing import Any, Dict, List, Optional

from .base import BaseGoHighLevelClient


class WorkflowsClient(BaseGoHighLevelClient):
    """Client for workflow and contact notes endpoints"""

    # ── Workflows ─────────────────────────────────────────────────────────────

    async def get_workflows(self, location_id: str) -> List[Dict[str, Any]]:
        """List all published workflows for a location"""
        response = await self._request(
            "GET",
            "/workflows",
            params={"locationId": location_id},
            location_id=location_id,
        )
        return response.json().get("workflows", [])

    async def add_contact_to_workflow(
        self,
        contact_id: str,
        workflow_id: str,
        location_id: str,
        event_start_time: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Add a contact to a workflow (triggers the automation sequence)"""
        payload: Dict[str, Any] = {}
        if event_start_time:
            payload["eventStartTime"] = event_start_time
        response = await self._request(
            "POST",
            f"/contacts/{contact_id}/workflow/{workflow_id}",
            json=payload,
            location_id=location_id,
        )
        return response.json() if response.content else {"success": True}

    async def remove_contact_from_workflow(
        self,
        contact_id: str,
        workflow_id: str,
        location_id: str,
    ) -> bool:
        """Remove a contact from a workflow"""
        response = await self._request(
            "DELETE",
            f"/contacts/{contact_id}/workflow/{workflow_id}",
            location_id=location_id,
        )
        return response.status_code in (200, 204)

    # ── Contact Notes ─────────────────────────────────────────────────────────

    async def get_contact_notes(
        self, contact_id: str, location_id: str
    ) -> List[Dict[str, Any]]:
        """Get all notes for a contact"""
        response = await self._request(
            "GET",
            f"/contacts/{contact_id}/notes",
            location_id=location_id,
        )
        return response.json().get("notes", [])

    async def create_contact_note(
        self,
        contact_id: str,
        body: str,
        location_id: str,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Create a note on a contact"""
        payload: Dict[str, Any] = {"body": body}
        if user_id:
            payload["userId"] = user_id
        response = await self._request(
            "POST",
            f"/contacts/{contact_id}/notes",
            json=payload,
            location_id=location_id,
        )
        return response.json().get("note", response.json())

    async def update_contact_note(
        self, contact_id: str, note_id: str, body: str, location_id: str
    ) -> Dict[str, Any]:
        """Update a contact note"""
        response = await self._request(
            "PUT",
            f"/contacts/{contact_id}/notes/{note_id}",
            json={"body": body},
            location_id=location_id,
        )
        return response.json().get("note", response.json())

    async def delete_contact_note(
        self, contact_id: str, note_id: str, location_id: str
    ) -> bool:
        """Delete a contact note"""
        response = await self._request(
            "DELETE",
            f"/contacts/{contact_id}/notes/{note_id}",
            location_id=location_id,
        )
        return response.status_code in (200, 204)
