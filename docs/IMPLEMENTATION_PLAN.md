# Mesh — Implementation Plan

> Autonomous AI-agent economy on Monad.
> Hackathon-first: deliver a working end-to-end demo before optimizing.

---

## 1. Repository Structure

```
mesh/
├── apps/
│   ├── web/                    # Next.js 15 frontend
│   │   ├── app/
│   │   │   ├── page.tsx
│   │   │   ├── tasks/
│   │   │   │   ├── page.tsx
│   │   │   │   └── new/page.tsx
│   │   │   ├── tasks/[id]/page.tsx
│   │   │   ├── agents/page.tsx
│   │   │   ├── agents/[id]/page.tsx
│   │   │   └── activity/page.tsx
│   │   └── components/
│   │       ├── TaskCard.tsx
│   │       ├── AgentCard.tsx
│   │       ├── AgentGraph.tsx
│   │       ├── TransactionRow.tsx
│   │       ├── ReputationBadge.tsx
│   │       └── WalletButton.tsx
│   └── api/                    # Python FastAPI backend
│       ├── app/
│       │   ├── main.py
│       │   ├── api/
│       │   │   └── routes/
│       │   │       ├── tasks.py
│       │   │       ├── agents.py
│       │   │       ├── reputation.py
│       │   │       └── blockchain.py
│       │   ├── agents/
│       │   │   ├── base.py
│       │   │   ├── coordinator.py
│       │   │   ├── researcher.py
│       │   │   ├── analyst.py
│       │   │   └── verifier.py
│       │   ├── blockchain/
│       │   │   ├── client.py
│       │   │   ├── contracts.py
│       │   │   └── transactions.py
│       │   ├── services/
│       │   │   ├── task_service.py
│       │   │   ├── agent_service.py
│       │   │   └── settlement_service.py
│       │   ├── providers/
│       │   │   ├── base.py
│       │   │   ├── openai.py
│       │   │   └── mock.py
│       │   ├── schemas/
│       │   │   ├── task.py
│       │   │   ├── agent.py
│       │   │   └── blockchain.py
│       │   ├── models/
│       │   │   ├── task.py
│       │   │   └── agent.py
│       │   └── core/
│       │       ├── config.py
│       │       └── logging.py
├── contracts/
│   ├── src/
│   │   ├── AgentRegistry.sol
│   │   ├── TaskMarket.sol
│   │   └── ReputationManager.sol
│   └── test/
│       ├── AgentRegistry.t.sol
│       ├── TaskMarket.t.sol
│       └── ReputationManager.t.sol
├── packages/
│   ├── sdk/
│   │   └── src/
│   │       └── index.ts
│   └── shared/
│       └── src/
│           └── index.ts
├── docs/
│   ├── architecture.md
│   ├── contracts.md
│   ├── api.md
│   └── demo.md
├── scripts/
├── deployments/
│   └── monad.json
├── .env.example
├── docker-compose.yml
├── kilo.jsonc
└── README.md
```

---

## 2. Architectural Components

| Layer | Responsibility |
|---|---|
| Web (Next.js) | Wallet connection, task creation, task detail, agent marketplace, live transaction feed |
| API (FastAPI) | Task orchestration, agent execution, settlement, blockchain relay |
| Agents | Coordinator, Researcher, Analyst, Verifier — provider-agnostic |
| Blockchain (Monad) | Agent identity, task escrow, settlement, reputation, result hashes |
| Database (PostgreSQL) | Off-chain state: tasks, executions, agent metadata, event log |

---

## 3. Smart Contract Responsibilities

### AgentRegistry.sol
- `registerAgent(metadataURI)` — register an AI agent identity
- `updateAgentMetadata(uri)` — update agent metadata
- `getAgent(id)` — read agent profile
- `setAgentActive(id, active)` — toggle agent availability
- Events: `AgentRegistered`, `AgentUpdated`, `AgentStatusChanged`

### TaskMarket.sol
- `createTask(budget, requestHash)` — create task, escrow MON
- `assignAgent(taskId, agentId)` — coordinator assigns worker
- `startTask(taskId)` — mark task running
- `submitResult(taskId, resultHash)` — submit canonical result hash
- `completeTask(taskId)` — release escrow, trigger reputation
- `cancelTask(taskId)` — refund requester
- Events: `TaskCreated`, `AgentAssigned`, `TaskStarted`, `ResultSubmitted`, `TaskCompleted`, `TaskCancelled`

### ReputationManager.sol
- `increaseReputation(agentId, delta)` — authorized only by TaskMarket
- `decreaseReputation(agentId, delta)` — authorized only by TaskMarket
- `getReputation(agentId)` — read reputation
- Events: `ReputationIncreased`, `ReputationDecreased`

---

## 4. API Design

```
POST   /tasks                  Create a new task
GET    /tasks                  List tasks
GET    /tasks/{id}             Get task detail
POST   /tasks/{id}/execute     Trigger agent execution
GET    /tasks/{id}/events      SSE stream of task events

POST   /agents                 Register agent
GET    /agents                 List agents
GET    /agents/{id}            Get agent profile
GET    /agents/{id}/reputation Get agent reputation

GET    /chain/transaction/{hash}  Get transaction details
GET    /chain/task/{id}           Get on-chain task state
```

---

## 5. Database Schema

```sql
-- agents
CREATE TABLE agents (
    id SERIAL PRIMARY KEY,
    wallet_address VARCHAR(42) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    description TEXT,
    metadata_uri TEXT,
    reputation INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- tasks
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    chain_task_id INTEGER UNIQUE,
    creator VARCHAR(42) NOT NULL,
    description TEXT NOT NULL,
    request_hash BYTEA NOT NULL,
    result_hash BYTEA,
    budget NUMERIC(20, 18) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'created',
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- executions
CREATE TABLE executions (
    id SERIAL PRIMARY KEY,
    task_id INTEGER REFERENCES tasks(id),
    agent_id INTEGER REFERENCES agents(id),
    role VARCHAR(50) NOT NULL,
    input JSONB,
    output JSONB,
    confidence NUMERIC(5, 4),
    payment NUMERIC(20, 18),
    transaction_hash BYTEA,
    created_at TIMESTAMP DEFAULT NOW()
);

-- events
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    task_id INTEGER REFERENCES tasks(id),
    type VARCHAR(100) NOT NULL,
    data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 6. Frontend Routes

| Route | Purpose |
|---|---|
| `/` | Landing page — headline + CTA |
| `/tasks` | Task list |
| `/tasks/new` | Create task form |
| `/tasks/[id]` | Task execution screen with agent graph |
| `/agents` | Agent marketplace |
| `/agents/[id]` | Agent reputation profile |
| `/activity` | Live transaction / event feed |

---

## 6a. Emerging Standards Alignment (Hackathon Credibility)

### ERC-8004: Trustless Agents
Mesh agent identity should align with [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004) where practical:
- **Identity Registry**: Our `AgentRegistry.sol` maps conceptually to ERC-8004 Identity Registry (ERC-721 + URIStorage).
- **Reputation Registry**: Our `ReputationManager.sol` maps conceptually to ERC-8004 Reputation Registry.
- **Validation Registry**: Our verifier agent workflow maps conceptually to ERC-8004 Validation Registry.

Alignment benefits:
- Judges recognize the standard.
- Future interoperability with other ERC-8004 agents.
- Agent metadata URI should follow ERC-8004 registration file schema.

### x402: Internet-Native Payments
Consider x402 as a **sponsor bounty integration** (MESH-6xx):
- Open standard for HTTP micropayments (HTTP 402).
- Coinbase CDP provides hosted facilitator with free tier (1,000 tx/month).
- Enables agent-to-agent payments over HTTP.
- Adds sponsor compatibility (Coinbase/CDP bounty).

### A2A: Agent-to-Agent Protocol
Agent communication should use [A2A protocol](https://github.com/google-a2a/A2A) concepts:
- Agent Cards at `/.well-known/agent-card.json` for discovery.
- JSON-RPC 2.0 for task submission.
- SSE for streaming task status.
- Official SDKs available in Python (`a2a-sdk`) and TypeScript (`@a2a-js/sdk`).

### Monad Foundry
Use **Foundry v1.8+** (official release, not the legacy `category-labs/foundry` fork):
- `forge build`, `forge test`, `forge script` work with Monad EVM automatically when `network = "monad"` is set in `foundry.toml`.
- `anvil --network monad` for local Monad node.
- Forking: `anvil --fork-url https://testnet-rpc.monad.xyz` (Monad EVM activates automatically via chain ID detection).

### Supabase + FastAPI Pattern
For hackathon speed:
- **Frontend → Supabase directly** for simple CRUD (agents list, task list).
- **FastAPI** for orchestration (AI workflow, blockchain settlement, escrow).
- Use **Supabase Auth** or demo-mode "acting as" for wallet-less testing.
- Enable **RLS** on all tables.
- Use **Edge Functions** only for webhooks and secret operations.

### Hackathon Judging Insights (Metropolis / past Monad events)
Winning projects commonly feature:
- **Instant on-chain settlement** with visible explorer links.
- **AI-powered** decision making with verifiable outputs.
- **Polished demo flow**: wallet connect → create task → escrow → AI execution → payment → reputation.
- **Proof of work**: on-chain result hashes, receipt NFTs, or verifiable credentials.
- **Walletless onboarding** (embedded wallets, passkeys) for non-crypto users.
- **Real-time UI**: SSE/WebSocket for live transaction feeds.

Target track: **"Trust, Identity & AI"** ($30,000 track prize at Monad Metropolis).

---

## 7. Agent Execution Lifecycle

```python
async def execute_task(task_id: int):
    task = await task_service.get(task_id)
    plan = await coordinator.plan(task)

    research = await researcher.run(plan.research_task)
    await event_bus.emit(task_id, "AGENT_COMPLETED", {"role": "researcher"})

    analysis = await analyst.run(research)
    await event_bus.emit(task_id, "AGENT_COMPLETED", {"role": "analyst"})

    verification = await verifier.run(task, research, analysis)
    await event_bus.emit(task_id, "AGENT_COMPLETED", {"role": "verifier"})

    if verification.approved:
        result_hash = hash_result(verification.output)
        await blockchain.submit_result(task.chain_task_id, result_hash)
        await settlement.pay_agents(task, plan.allocations)
        await reputation_service.update(task)
        await event_bus.emit(task_id, "TASK_COMPLETED", {"result_hash": result_hash})
```

---

## 8. Environment Variables

```env
# App
DATABASE_URL=
API_PORT=
WEB_URL=
NEXT_PUBLIC_API_URL=

# Blockchain
MONAD_RPC_URL=
MONAD_CHAIN_ID=
AGENT_REGISTRY_ADDRESS=
TASK_MARKET_ADDRESS=
REPUTATION_MANAGER_ADDRESS=
PRIVATE_KEY=          # backend signer only

# AI
OPENAI_API_KEY=
GEMINI_API_KEY=
DEFAULT_LLM_PROVIDER=

# Supabase / Postgres
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Frontend
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=
NEXT_PUBLIC_MONAD_RPC_URL=
```

---

## 9. Testing Strategy

| Layer | Tool | Focus |
|---|---|---|
| Smart contracts | Foundry | Unit + fuzz + invariant |
| Backend | pytest | Unit + integration |
| Frontend | Vitest + Playwright | Component + E2E |
| AI agents | pytest + mocks | Deterministic interface contract |

---

## 10. Deployment Strategy

| Component | Target |
|---|---|
| Frontend | Vercel |
| Backend | Railway / Render |
| Database | Supabase |
| Contracts | Monad testnet → mainnet |
| SDK | npm / GitHub Packages |

---

## 11. Security Risks

| Risk | Mitigation |
|---|---|
| Reentrancy in settlement | ReentrancyGuard, checks-effects-interactions |
| Double payment | Track paid executions per task on-chain |
| Unauthorized reputation update | Only TaskMarket can call ReputationManager |
| Result tampering after settlement | Result hash is immutable once submitted |
| Frontend RPC manipulation | Backend validates all on-chain state |
| LLM prompt injection | Validate all agent outputs against schemas |

---

## 12. Ticket Backlog

### Phase 0 — Bootstrap

#### MESH-001 — Repository Bootstrap
**Objective:** Create monorepo, verify all sub-projects run, add configuration.
**Files affected:** Root level files, package.json, foundry.toml, requirements.txt, tsconfig.json
**Implementation steps:**
1. Initialize git repo.
2. Create directory structure.
3. Add `.gitignore`, `.env.example`, `README.md`.
4. Add `foundry.toml` for contracts.
5. Add `requirements.txt` for backend.
6. Add `package.json` for web and sdk.
7. Verify `forge build`, `pytest --collect-only`, `npm run dev` all pass.
**Acceptance criteria:**
- Monorepo structure matches §1.
- `forge build` compiles contracts.
- Backend imports resolve.
- `npm run dev` starts Next.js.
- `.env.example` lists all variables from §8.
**Dependencies:** None.

---

### Phase 1 — Smart Contracts

#### MESH-101 — AgentRegistry.sol
**Objective:** Implement agent identity contract with registration, metadata, and active status.
**Files affected:** `contracts/src/AgentRegistry.sol`, `contracts/test/AgentRegistry.t.sol`
**Implementation steps:**
1. Write `AgentRegistry.sol` with `Agent` struct, `registerAgent`, `updateAgentMetadata`, `getAgent`, `setAgentActive`.
2. Emit events for all state changes.
3. Write Foundry tests covering: registration, duplicate, metadata update, active toggle, unauthorized calls.
4. Run `forge test`.
**Acceptance criteria:**
- Contract compiles.
- All tests pass.
- Events emitted for all state transitions.
**Dependencies:** MESH-001.

#### MESH-102 — TaskMarket.sol (Core)
**Objective:** Implement task creation, escrow, assignment, and completion.
**Files affected:** `contracts/src/TaskMarket.sol`, `contracts/test/TaskMarket.t.sol`
**Implementation steps:**
1. Write `TaskMarket.sol` with `Task` struct and `TaskStatus` enum.
2. Implement `createTask` with MON escrow.
3. Implement `assignAgent`, `startTask`, `submitResult`, `completeTask`, `cancelTask`.
4. Write Foundry tests covering all happy paths and key failure modes.
5. Run `forge test`.
**Acceptance criteria:**
- Contract compiles.
- All tests pass.
- Escrow releases only on completion.
- Events emitted for all state transitions.
**Dependencies:** MESH-101.

#### MESH-103 — Escrow & Payments
**Objective:** Implement MON escrow hold/release with multi-agent payment split.
**Files affected:** `contracts/src/TaskMarket.sol`
**Implementation steps:**
1. Ensure `createTask` transfers MON into contract.
2. Ensure `completeTask` distributes to assigned agents.
3. Ensure `cancelTask` refunds requester.
4. Add tests for partial assignment and cancellation.
**Acceptance criteria:**
- Balances match expected splits.
- Refund works on cancellation.
- No funds stuck after completion.
**Dependencies:** MESH-102.

#### MESH-104 — ReputationManager.sol
**Objective:** Implement reputation increase/decrease with TaskMarket authorization.
**Files affected:** `contracts/src/ReputationManager.sol`, `contracts/test/ReputationManager.t.sol`
**Implementation steps:**
1. Write `ReputationManager.sol`.
2. Restrict updates to TaskMarket address.
3. Write tests for increase, decrease, unauthorized calls.
4. Run `forge test`.
**Acceptance criteria:**
- Contract compiles.
- Only TaskMarket can modify reputation.
- All tests pass.
**Dependencies:** MESH-101, MESH-102.

#### MESH-105 — Contract Deployment Config
**Objective:** Store deployment addresses and add deployment script.
**Files affected:** `deployments/monad.json`, `scripts/deploy.py` or Foundry script
**Implementation steps:**
1. Write Foundry deployment script.
2. Deploy to Monad testnet (or local anvil for dev).
3. Store addresses in `deployments/monad.json`.
4. Verify backend can read addresses from config.
**Acceptance criteria:**
- Deployment script runs successfully.
- `deployments/monad.json` contains contract addresses.
**Dependencies:** MESH-101, MESH-102, MESH-104.

---

### Phase 2 — Backend

#### MESH-201 — FastAPI Project Setup
**Objective:** Create FastAPI app with health check, CORS, config, and logging.
**Files affected:** `apps/api/app/main.py`, `apps/api/app/core/config.py`, `apps/api/app/core/logging.py`, `requirements.txt`
**Implementation steps:**
1. Initialize FastAPI app.
2. Add config loader (pydantic-settings).
3. Add structured logging.
4. Add `/health` endpoint.
5. Add CORS middleware.
6. Run `uvicorn` and verify.
**Acceptance criteria:**
- Server starts without errors.
- `/health` returns 200.
- Config loads from environment.
**Dependencies:** MESH-001.

#### MESH-202 — Agent Model + CRUD
**Objective:** Implement agent database model and CRUD API.
**Files affected:** `apps/api/app/models/agent.py`, `apps/api/app/schemas/agent.py`, `apps/api/app/api/routes/agents.py`, `apps/api/app/services/agent_service.py`
**Implementation steps:**
1. Define SQLAlchemy `Agent` model.
2. Define Pydantic schemas.
3. Implement CRUD service.
4. Implement REST routes.
5. Run `pytest`.
**Acceptance criteria:**
- Create, read, list agents via API.
- Database migrations or schema creation works.
**Dependencies:** MESH-201.

#### MESH-203 — Task Model + CRUD
**Objective:** Implement task database model and CRUD API.
**Files affected:** `apps/api/app/models/task.py`, `apps/api/app/schemas/task.py`, `apps/api/app/api/routes/tasks.py`, `apps/api/app/services/task_service.py`
**Implementation steps:**
1. Define SQLAlchemy `Task` and `Execution` models.
2. Define Pydantic schemas.
3. Implement task service.
4. Implement REST routes.
5. Run `pytest`.
**Acceptance criteria:**
- Create, read, list tasks via API.
- Task status transitions persist correctly.
**Dependencies:** MESH-202.

#### MESH-204 — LLM Provider Abstraction
**Objective:** Implement provider-agnostic LLM interface with OpenAI and Mock providers.
**Files affected:** `apps/api/app/providers/base.py`, `apps/api/app/providers/openai.py`, `apps/api/app/providers/mock.py`
**Implementation steps:**
1. Define `LLMProvider` abstract base class.
2. Implement `OpenAIProvider`.
3. Implement `MockProvider` for offline demos.
4. Add provider selection via config.
5. Run tests.
**Acceptance criteria:**
- Both providers return valid structured output.
- Provider is swappable via environment variable.
**Dependencies:** MESH-201.

#### MESH-205 — Research Agent
**Objective:** Implement Research agent with typed input/output schemas.
**Files affected:** `apps/api/app/agents/base.py`, `apps/api/app/agents/researcher.py`, `apps/api/app/schemas/agent.py`
**Implementation steps:**
1. Define `AgentTask` and `AgentResult` schemas.
2. Implement `ResearchAgent` using provider abstraction.
3. Add prompt template for research tasks.
4. Run tests.
**Acceptance criteria:**
- Agent accepts structured task and returns structured result.
- Output validates against schema.
**Dependencies:** MESH-204.

#### MESH-206 — Analyst Agent
**Objective:** Implement Analyst agent for reasoning over research results.
**Files affected:** `apps/api/app/agents/analyst.py`
**Implementation steps:**
1. Define analyst prompt template.
2. Implement `AnalystAgent`.
3. Validate output schema.
4. Run tests.
**Acceptance criteria:**
- Agent accepts research output and returns structured conclusion.
**Dependencies:** MESH-205.

#### MESH-207 — Verifier Agent
**Objective:** Implement Verifier agent that approves or rejects results.
**Files affected:** `apps/api/app/agents/verifier.py`
**Implementation steps:**
1. Define verifier prompt template.
2. Implement `VerifierAgent` returning `approved`, `confidence`, `issues`.
3. Run tests.
**Acceptance criteria:**
- Agent returns structured verification result.
**Dependencies:** MESH-205, MESH-206.

#### MESH-208 — Coordinator Agent
**Objective:** Implement Coordinator that decomposes tasks and allocates budget.
**Files affected:** `apps/api/app/agents/coordinator.py`
**Implementation steps:**
1. Define coordinator prompt template.
2. Implement `CoordinatorAgent` that produces execution plan.
3. Validate plan structure.
4. Run tests.
**Acceptance criteria:**
- Coordinator produces valid execution plan with agent allocations.
**Dependencies:** MESH-205, MESH-206, MESH-207.

#### MESH-209 — Blockchain Client
**Objective:** Implement viem/wagmi-based blockchain client for Monad.
**Files affected:** `apps/api/app/blockchain/client.py`, `apps/api/app/blockchain/contracts.py`
**Implementation steps:**
1. Configure Monad RPC client.
2. Load contract ABIs and addresses.
3. Implement read methods: `getAgent`, `getTask`, `getReputation`.
4. Run tests against local fork or testnet.
**Acceptance criteria:**
- Client can read on-chain state.
- ABIs match deployed contracts.
**Dependencies:** MESH-105.

#### MESH-210 — Settlement Service
**Objective:** Implement on-chain settlement and reputation updates.
**Files affected:** `apps/api/app/blockchain/transactions.py`, `apps/api/app/services/settlement_service.py`
**Implementation steps:**
1. Implement `submitResult`, `completeTask` transaction senders.
2. Implement reputation update relay.
3. Add transaction confirmation and retry logic.
4. Run tests.
**Acceptance criteria:**
- Successful execution writes result hash and pays agents.
- Reputation updates are authorized correctly.
**Dependencies:** MESH-209, MESH-208.

---

### Phase 3 — Frontend

#### MESH-301 — Landing Page
**Objective:** Build polished landing page with headline and CTAs.
**Files affected:** `apps/web/app/page.tsx`
**Implementation steps:**
1. Create landing layout with Tailwind.
2. Add headline and subtitle.
3. Add "Launch Mesh" and "Explore Agents" buttons.
4. Verify responsive design.
**Acceptance criteria:**
- Page renders correctly on desktop and mobile.
**Dependencies:** MESH-001.

#### MESH-302 — Wallet Connection
**Objective:** Integrate wagmi/viem wallet connection.
**Files affected:** `apps/web/components/WalletButton.tsx`, `apps/web/app/providers.tsx`
**Implementation steps:**
1. Configure wagmi with Monad chain.
2. Create `WalletButton` component.
3. Wrap app in wagmi provider.
4. Add connection states.
**Acceptance criteria:**
- User can connect/disconnect wallet.
- Address displays when connected.
**Dependencies:** MESH-301.

#### MESH-303 — Task Creation
**Objective:** Build task creation form with description, budget, and type.
**Files affected:** `apps/web/app/tasks/new/page.tsx`
**Implementation steps:**
1. Create form with description, budget input, task type selector.
2. Connect to `POST /tasks` API.
3. Handle loading and error states.
4. Redirect to task detail on success.
**Acceptance criteria:**
- Form submits and creates task.
- Validation prevents empty or invalid inputs.
**Dependencies:** MESH-302, MESH-203.

#### MESH-304 — Task Detail Page
**Objective:** Build task detail page with status and execution info.
**Files affected:** `apps/web/app/tasks/[id]/page.tsx`
**Implementation steps:**
1. Fetch task by ID.
2. Display task metadata, status, budget.
3. Show execution history.
4. Add "Execute" button for unstarted tasks.
**Acceptance criteria:**
- Task details render correctly.
- Status updates reflect on-chain state.
**Dependencies:** MESH-303, MESH-203.

#### MESH-305 — Agent Graph
**Objective:** Visualize coordinator → agents → verifier execution flow.
**Files affected:** `apps/web/components/AgentGraph.tsx`
**Implementation steps:**
1. Create graph component using SVG or simple div layout.
2. Map execution roles to nodes.
3. Animate status transitions.
4. Integrate into task detail page.
**Acceptance criteria:**
- Graph shows coordinator, researcher, analyst, verifier.
- Nodes update status in real time.
**Dependencies:** MESH-304.

#### MESH-306 — Live Transaction Feed
**Objective:** Build right sidebar showing live settlement events.
**Files affected:** `apps/web/app/tasks/[id]/page.tsx`, `apps/web/components/TransactionRow.tsx`
**Implementation steps:**
1. Create `TransactionRow` component.
2. Connect to SSE endpoint `/tasks/{id}/events`.
3. Render events with timestamps and explorer links.
**Acceptance criteria:**
- Events stream in real time.
- Each event shows transaction hash and explorer link.
**Dependencies:** MESH-304.

#### MESH-307 — Agent Marketplace
**Objective:** Build agent list page with cards showing reputation and stats.
**Files affected:** `apps/web/app/agents/page.tsx`, `apps/web/components/AgentCard.tsx`
**Implementation steps:**
1. Fetch agents from API.
2. Create agent card with stats.
3. Add "Hire Agent" button (placeholder for MVP).
4. Verify responsive layout.
**Acceptance criteria:**
- All registered agents display.
- Cards show reputation and task count.
**Dependencies:** MESH-304.

#### MESH-308 — Agent Reputation Profile
**Objective:** Build individual agent profile page.
**Files affected:** `apps/web/app/agents/[id]/page.tsx`
**Implementation steps:**
1. Fetch agent detail and reputation.
2. Display agent info, reputation score, task history.
3. Add blockchain explorer link.
**Acceptance criteria:**
- Profile shows accurate on-chain and off-chain data.
**Dependencies:** MESH-307.

---

### Phase 4 — End-to-End Integration

#### MESH-401 — Create Task from UI
**Objective:** Wire task creation form to backend and blockchain.
**Files affected:** `apps/web/app/tasks/new/page.tsx`, `apps/api/app/api/routes/tasks.py`
**Implementation steps:**
1. Frontend submits task to backend.
2. Backend creates off-chain task.
3. Backend calls `createTask` on TaskMarket.
4. Backend stores `chain_task_id`.
5. Return task detail to frontend.
**Acceptance criteria:**
- Task created end-to-end from UI.
- `chain_task_id` stored in database.
**Dependencies:** MESH-303, MESH-210.

#### MESH-402 — Run AI Workflow
**Objective:** Execute coordinator → researcher → analyst → verifier pipeline.
**Files affected:** `apps/api/app/services/task_service.py`, `apps/api/app/agents/coordinator.py`
**Implementation steps:**
1. Implement `execute_task` orchestration.
2. Emit SSE events at each stage.
3. Validate all agent outputs.
4. Run full pipeline on a test task.
**Acceptance criteria:**
- Full AI workflow completes successfully.
- Events emitted at each stage.
**Dependencies:** MESH-208, MESH-209, MESH-210.

#### MESH-403 — Settle Agents
**Objective:** Pay agents on-chain after successful verification.
**Files affected:** `apps/api/app/services/settlement_service.py`
**Implementation steps:**
1. After verification, compute payment splits.
2. Call `completeTask` on TaskMarket.
3. Record transactions in `executions` table.
4. Emit payment events.
**Acceptance criteria:**
- Agents receive correct MON amounts.
- Payments recorded in database.
**Dependencies:** MESH-402, MESH-210.

#### MESH-404 — Write Result Hash
**Objective:** Submit canonical result hash to Monad.
**Files affected:** `apps/api/app/blockchain/transactions.py`
**Implementation steps:**
1. Hash final result deterministically.
2. Submit `submitResult` transaction.
3. Store `resultHash` in task record.
**Acceptance criteria:**
- Result hash stored on-chain.
- Frontend can verify hash.
**Dependencies:** MESH-402.

#### MESH-405 — Update Reputation
**Objective:** Update agent reputation on-chain after task completion.
**Files affected:** `apps/api/app/services/settlement_service.py`
**Implementation steps:**
1. After payment, call `increaseReputation` for each agent.
2. Compute deltas based on role and verification confidence.
3. Emit reputation events.
**Acceptance criteria:**
- Reputation scores update on-chain.
- Events visible in UI.
**Dependencies:** MESH-403, MESH-404.

#### MESH-406 — Show Explorer Links
**Objective:** Display Monad explorer links for all transactions.
**Files affected:** `apps/web/components/TransactionRow.tsx`, `apps/web/app/tasks/[id]/page.tsx`
**Implementation steps:**
1. Add explorer base URL to config.
2. Render transaction links in transaction feed.
3. Add links to task detail page.
**Acceptance criteria:**
- All transactions link to Monad explorer.
- Links open in new tab.
**Dependencies:** MESH-305, MESH-306.

---

### Phase 5 — Polish

#### MESH-501 — Loading States
**Objective:** Add loading skeletons and spinners throughout the UI.
**Files affected:** Multiple frontend components
**Implementation steps:**
1. Create shared `Loading` component.
2. Add skeletons to task list, task detail, agent cards.
3. Add spinner to transaction feed.
**Acceptance criteria:**
- No raw empty states during data fetches.
**Dependencies:** MESH-401.

#### MESH-502 — Error States
**Objective:** Handle and display errors gracefully.
**Files affected:** Multiple frontend components, backend routes
**Implementation steps:**
1. Add error boundaries to key pages.
2. Display user-friendly error messages.
3. Add retry buttons where applicable.
**Acceptance criteria:**
- Errors display clearly without crashing the app.
**Dependencies:** MESH-501.

#### MESH-503 — Mobile Responsiveness
**Objective:** Ensure UI works on mobile devices.
**Files affected:** All frontend pages and components
**Implementation steps:**
1. Audit layout on mobile viewports.
2. Fix overflow and spacing issues.
3. Test navigation on small screens.
**Acceptance criteria:**
- All pages usable on 320px+ width.
**Dependencies:** MESH-501.

#### MESH-504 — Demo Seed Data
**Objective:** Populate database with demo agents and tasks for presentation.
**Files affected:** `scripts/seed.py`
**Implementation steps:**
1. Create seed script.
2. Insert 8–12 demo agents with varied reputations.
3. Insert 5–10 demo tasks in various states.
4. Document seed command.
**Acceptance criteria:**
- Running seed script populates demo-ready data.
**Dependencies:** MESH-202, MESH-203.

#### MESH-505 — Analytics
**Objective:** Add basic network stats to dashboard.
**Files affected:** `apps/web/app/page.tsx`, `apps/api/app/api/routes/`
**Implementation steps:**
1. Add stats endpoint: total agents, tasks, MON settled, transactions.
2. Display stats on landing page.
3. Add simple chart or counter UI.
**Acceptance criteria:**
- Dashboard shows live network statistics.
**Dependencies:** MESH-504.

#### MESH-506 — README
**Objective:** Write comprehensive project README.
**Files affected:** `README.md`
**Implementation steps:**
1. Write project description.
2. Add architecture diagram.
3. Add setup instructions.
4. Add demo walkthrough.
5. Add sponsor integration notes.
**Acceptance criteria:**
- README explains project, setup, and demo in < 5 min read.
**Dependencies:** MESH-401.

#### MESH-507 — Architecture Docs
**Objective:** Document architecture, contracts, API, and demo flow.
**Files affected:** `docs/architecture.md`, `docs/contracts.md`, `docs/api.md`, `docs/demo.md`
**Implementation steps:**
1. Write architecture overview.
2. Document contract interfaces.
3. Document API endpoints.
4. Write demo script for judges.
**Acceptance criteria:**
- All docs complete and accurate.
**Dependencies:** MESH-506.

---

### Phase 6 — Sponsor Bounties (post-MVP)

> Only implement after core demo is stable.

#### MESH-601 — Chainlink Integration
#### MESH-602 — Privy Authentication
#### MESH-603 — Alchemy RPC / Transfers
#### MESH-604 — Nansen Analytics
#### MESH-605 — Custom SDK Plugin

---

## 13. Minimum Demo Path (Critical Path)

```
MESH-001
  → MESH-101 → MESH-102 → MESH-103 → MESH-104 → MESH-105
  → MESH-201 → MESH-202 → MESH-203 → MESH-209 → MESH-210
  → MESH-301 → MESH-302 → MESH-303 → MESH-304 → MESH-306
  → MESH-401 → MESH-402 → MESH-403 → MESH-404 → MESH-405 → MESH-406
  → MESH-504 → MESH-506 → MESH-507
```

Everything else is polish.

---

## 14. Definition of Done

The following scenario must work reliably from a clean browser before submission:

1. Open Mesh.
2. Connect wallet.
3. Create task: "Analyze whether decentralized GPU markets could lower AI inference costs."
4. Deposit task budget.
5. UI displays: Coordinator selected.
6. Researcher executes.
7. Research payment settles.
8. Analyst executes.
9. Analyst payment settles.
10. Verifier evaluates result.
11. Result hash submitted.
12. Reputation scores update.
13. Final report appears.
14. Every transaction has a Monad explorer link.

If all 14 work reliably, stop adding major features. Polish it.

---

## 15. Completed Tickets

#### MESH-001 — Repository Bootstrap ✅
- Monorepo structure created with pnpm workspaces
- Foundry v1.8+ configuration for Monad in `contracts/foundry.toml`
- FastAPI backend skeleton with health check
- Next.js 15 frontend skeleton with Tailwind CSS
- `.env.example`, `docker-compose.yml`, `README.md`
- Backend tests passing (2/2)

#### MESH-101 — AgentRegistry.sol ✅
- ERC-721 based agent identity contract with ERC721URIStorage and ERC721Enumerable
- Agent struct: owner, reputation, completedTasks, totalEarned, active
- Events: AgentRegistered, AgentUpdated, AgentStatusChanged
- Foundry tests: registration, metadata updates, active toggle, unauthorized access, non-existent agent
- Aligned with ERC-8004 Identity Registry concepts

#### MESH-102 — TaskMarket.sol ✅
- Native MON escrow via payable `createTask`
- Agent assignment, task start, result submission, completion, and cancellation
- Events: TaskCreated, AgentAssigned, TaskStarted, ResultSubmitted, TaskCompleted, TaskCancelled

#### MESH-103 — Escrow & Payments ✅
- `completeTask` splits budget equally among assigned agents via `.call{value:}`
- `cancelTask` refunds exact budget to requester
- `nonReentrant` on state-changing payment functions

#### MESH-104 — ReputationManager.sol ✅
- Restricted to TaskMarket authorization
- increaseReputation / decreaseReputation with underflow protection
- Events: ReputationIncreased, ReputationDecreased

#### MESH-102B — Smart Contract Verification and CI ✅
- Fixed `assignAgent` authorization: only requester can assign
- Fixed `completeTask` authorization: only requester can complete
- Fixed `submitResult` to prevent result hash overwrite
- Expanded TaskMarket tests to 18 cases covering all required reverts and balances
- Total Solidity tests: 31
- GitHub Actions CI added: `forge fmt --check`, `forge build`, `forge test -vvv`
- Security hardening: reentrancy guards, checks-effects-interactions, zero-address validation

---

*Last updated: 2026-10-04*
