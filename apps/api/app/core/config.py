from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    DATABASE_URL: str = ""
    API_PORT: int = 8000
    WEB_URL: str = "http://localhost:3000"
    NEXT_PUBLIC_API_URL: str = "http://localhost:8000"

    # Blockchain
    MONAD_RPC_URL: str = "https://testnet-rpc.monad.xyz"
    MONAD_CHAIN_ID: int = 10143
    AGENT_REGISTRY_ADDRESS: str = ""
    TASK_MARKET_ADDRESS: str = ""
    REPUTATION_MANAGER_ADDRESS: str = ""
    PRIVATE_KEY: str = ""

    # AI
    OPENAI_API_KEY: str = ""
    GEMINI_API_KEY: str = ""
    DEFAULT_LLM_PROVIDER: str = "mock"

    # Supabase
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""


settings = Settings()
