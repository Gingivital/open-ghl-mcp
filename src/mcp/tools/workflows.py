"""Workflow and contact notes tools for GoHighLevel MCP integration"""

from typing import Any, Dict

from ..params.workflows import (
    AddToWorkflowParams,
    CreateContactNoteParams,
    DeleteContactNoteParams,
    GetContactNotesParams,
    GetWorkflowsParams,
    RemoveFromWorkflowParams,
    UpdateContactNoteParams,
)

mcp = None
get_client = None


def _register_workflow_tools(_mcp, _get_client):
    global mcp, get_client
    mcp = _mcp
    get_client = _get_client

    @mcp.tool()
    async def get_workflows(params: GetWorkflowsParams) -> Dict[str, Any]:
        """List all published workflows for a location.

        Use this to discover workflow IDs before calling add_to_workflow.
        Returns id, name, status, and trigger info for each workflow.
        """
        client = await get_client(params.access_token)
        workflows = await client.get_workflows(params.location_id)
        return {"workflows": workflows, "count": len(workflows)}

    @mcp.tool()
    async def add_to_workflow(params: AddToWorkflowParams) -> Dict[str, Any]:
        """Add a contact to a GHL workflow, triggering its automation sequence.

        This is the core action for launching any agent sequence:
        - Scout sequence: workflow triggered by 'new_lead' tag workflow
        - Qualifier: triggered by 'awaiting_qualification' tag workflow
        - Closer: triggered by 'qualified_hot' tag workflow
        - Fulfillment: triggered by 'closed_won' tag workflow
        - Optimizer win-back: triggered by 7-day inactivity workflow

        Find workflow IDs with get_workflows first.
        """
        client = await get_client(params.access_token)
        result = await client.add_contact_to_workflow(
            contact_id=params.contact_id,
            workflow_id=params.workflow_id,
            location_id=params.location_id,
            event_start_time=params.event_start_time,
        )
        return {
            "success": True,
            "contact_id": params.contact_id,
            "workflow_id": params.workflow_id,
            "result": result,
        }

    @mcp.tool()
    async def remove_from_workflow(params: RemoveFromWorkflowParams) -> Dict[str, Any]:
        """Remove a contact from a workflow, stopping its automation sequence.

        Use when advancing a contact to the next agent — remove them from the
        current sequence before adding them to the next one to avoid overlapping messages.
        """
        client = await get_client(params.access_token)
        success = await client.remove_contact_from_workflow(
            contact_id=params.contact_id,
            workflow_id=params.workflow_id,
            location_id=params.location_id,
        )
        return {
            "success": success,
            "contact_id": params.contact_id,
            "workflow_id": params.workflow_id,
        }

    @mcp.tool()
    async def get_contact_notes(params: GetContactNotesParams) -> Dict[str, Any]:
        """Get all notes logged on a contact.

        Notes are used by the Fulfillment and Optimizer agents to track:
        - Milestone progress
        - Win captures (Day 5)
        - Escalation history
        - Optimizer decisions (DATE | METRIC | STATUS | ACTION TAKEN)
        """
        client = await get_client(params.access_token)
        notes = await client.get_contact_notes(params.contact_id, params.location_id)
        return {"notes": notes, "count": len(notes)}

    @mcp.tool()
    async def create_contact_note(params: CreateContactNoteParams) -> Dict[str, Any]:
        """Create a note on a contact.

        Required by the agent system for:
        - Optimizer reports: 'DATE | METRIC | STATUS (UP/DOWN) | ACTION TAKEN'
        - Fulfillment milestone tracking
        - Win capture on Day 5
        - Escalation flags for human team
        """
        client = await get_client(params.access_token)
        note = await client.create_contact_note(
            contact_id=params.contact_id,
            body=params.body,
            location_id=params.location_id,
            user_id=params.user_id,
        )
        return {"note": note}

    @mcp.tool()
    async def update_contact_note(params: UpdateContactNoteParams) -> Dict[str, Any]:
        """Update an existing note on a contact"""
        client = await get_client(params.access_token)
        note = await client.update_contact_note(
            contact_id=params.contact_id,
            note_id=params.note_id,
            body=params.body,
            location_id=params.location_id,
        )
        return {"note": note}

    @mcp.tool()
    async def delete_contact_note(params: DeleteContactNoteParams) -> Dict[str, Any]:
        """Delete a note from a contact"""
        client = await get_client(params.access_token)
        success = await client.delete_contact_note(
            contact_id=params.contact_id,
            note_id=params.note_id,
            location_id=params.location_id,
        )
        return {"success": success}
