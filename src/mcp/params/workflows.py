"""Parameter models for workflow and notes MCP tools"""

from typing import Optional
from pydantic import BaseModel, Field


class GetWorkflowsParams(BaseModel):
    location_id: str = Field(..., description="The location (sub-account) ID")
    access_token: Optional[str] = Field(
        None, description="Optional override access token"
    )


class AddToWorkflowParams(BaseModel):
    contact_id: str = Field(..., description="The contact ID to add to the workflow")
    workflow_id: str = Field(..., description="The workflow ID to add the contact to")
    location_id: str = Field(..., description="The location (sub-account) ID")
    event_start_time: Optional[str] = Field(
        None,
        description="ISO 8601 datetime to schedule the workflow start (e.g. 2025-06-10T09:00:00+00:00). Defaults to now.",
    )
    access_token: Optional[str] = Field(
        None, description="Optional override access token"
    )


class RemoveFromWorkflowParams(BaseModel):
    contact_id: str = Field(
        ..., description="The contact ID to remove from the workflow"
    )
    workflow_id: str = Field(
        ..., description="The workflow ID to remove the contact from"
    )
    location_id: str = Field(..., description="The location (sub-account) ID")
    access_token: Optional[str] = Field(
        None, description="Optional override access token"
    )


class GetContactNotesParams(BaseModel):
    contact_id: str = Field(..., description="The contact ID")
    location_id: str = Field(..., description="The location (sub-account) ID")
    access_token: Optional[str] = Field(
        None, description="Optional override access token"
    )


class CreateContactNoteParams(BaseModel):
    contact_id: str = Field(..., description="The contact ID")
    location_id: str = Field(..., description="The location (sub-account) ID")
    body: str = Field(..., description="Note content")
    user_id: Optional[str] = Field(None, description="User ID to attribute the note to")
    access_token: Optional[str] = Field(
        None, description="Optional override access token"
    )


class UpdateContactNoteParams(BaseModel):
    contact_id: str = Field(..., description="The contact ID")
    note_id: str = Field(..., description="The note ID to update")
    location_id: str = Field(..., description="The location (sub-account) ID")
    body: str = Field(..., description="Updated note content")
    access_token: Optional[str] = Field(
        None, description="Optional override access token"
    )


class DeleteContactNoteParams(BaseModel):
    contact_id: str = Field(..., description="The contact ID")
    note_id: str = Field(..., description="The note ID to delete")
    location_id: str = Field(..., description="The location (sub-account) ID")
    access_token: Optional[str] = Field(
        None, description="Optional override access token"
    )
