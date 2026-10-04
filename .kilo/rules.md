# Mesh Engineering Rules

## General

- Implement only the requested ticket.
- Never silently expand project scope.
- Prefer simple implementations over abstractions.
- Never hard-code secrets.
- Never commit .env.
- Keep dependencies minimal.
- Every feature requires error handling.

## Solidity

- Solidity contracts require tests.
- Follow checks-effects-interactions.
- Prevent reentrancy.
- Prevent double settlement.
- Validate zero addresses.
- Use custom errors where practical.
- Emit events for important state transitions.
- Never use tx.origin for authorization.

## Backend

- Use Python type hints.
- Use Pydantic models for all request/response objects.
- Async APIs where appropriate.
- Keep routes thin.
- Business logic belongs in services.
- LLM output must be validated before use.

## AI

- Never trust raw LLM output.
- Parse responses into typed schemas.
- Agents should have deterministic interfaces.
- Provider implementations must remain swappable.

## Frontend

- TypeScript strict mode.
- Avoid any unless unavoidable.
- Wallet states must be handled explicitly.
- Transactions require loading, confirmation and error states.
- Never claim an on-chain action completed before receipt confirmation.

## Testing

Before marking a ticket complete:

- run unit tests
- run type checking
- run lint
- run build if applicable

## Hackathon priority

Optimize for:

1. end-to-end functionality
2. reliability
3. visible Monad integration
4. strong demo UX
5. sponsor compatibility
6. additional features
