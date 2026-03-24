# Project Roadmap

This document outlines the development plan for the VaultTracker application.

## Phase 1: Solidify Existing Functionality with Tests

*   **Objective**: Complete the test suite for the `HomeViewModel` as detailed in `TODO_HomeViewModelTests.md`.
*   **Goal**: To create a stable foundation and ensure that the current client-side business logic is working as expected. These tests will serve as a safety net to prevent regressions during future refactoring.

## Phase 2: Full-Stack Development Training

*   **Objective**: Pause development on the iOS application to start a new project focused on learning full-stack development.
*   **Technology Focus**: Python with the FastAPI framework.

## Phase 3: Backend Integration ✓ COMPLETE

*   **Objective**: Return to the VaultTracker project to implement a custom backend API.
*   **Goal**: Refactor the existing data layer, replacing the local SwiftData implementation with network calls to the new FastAPI backend. The test suite from Phase 1 will be critical for verifying that the application's functionality remains intact after this significant change.
*   **Status**: Complete. SwiftData replaced by APIService/DataService; all CRUD operations backed by FastAPI endpoints. See `TODO_APIImplementation.md` for full task breakdown.
