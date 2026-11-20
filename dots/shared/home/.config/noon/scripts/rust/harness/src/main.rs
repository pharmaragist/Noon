use clap::{Parser, Subcommand};

mod acp;
mod attachments;
mod common;
mod config;
mod db;
mod events;

#[derive(Debug, Parser)]
#[command(name = "harness")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Sessions,
    Chat {
        session_id: String,
        #[arg(allow_hyphen_values = true)]
        limit: Option<i64>,
        #[arg(allow_hyphen_values = true)]
        offset: Option<i64>,
    },
    Skills,
    GenTools {
        shell_root: String,
    },
    SyncConfig {
        global_cfg: String,
        side_dir: String,
    },
    Acp,
}

fn init_tracing() {
    use tracing_subscriber::EnvFilter;

    let filter = EnvFilter::try_from_env("NOON_HARNESS_LOG")
        .unwrap_or_else(|_| EnvFilter::new("off"));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_writer(std::io::stderr)
        .init();
}

fn main() {
    init_tracing();
    let cli = Cli::parse();
    if let Err(err) = run(cli) {
        eprintln!("harness: {err}");
        std::process::exit(1);
    }
}

fn run(cli: Cli) -> anyhow::Result<()> {
    match cli.command {
        Command::Sessions => db::cmd_sessions()?,
        Command::Chat {
            session_id,
            limit,
            offset,
        } => db::cmd_chat(&session_id, limit.unwrap_or(10), offset.unwrap_or(0))?,
        Command::Skills => config::cmd_skills()?,
        Command::GenTools { shell_root } => config::cmd_gen_tools(&shell_root)?,
        Command::SyncConfig {
            global_cfg,
            side_dir,
        } => config::cmd_sync_config(&global_cfg, &side_dir)?,
        Command::Acp => smol::block_on(acp::cmd_acp())?,
    }
    Ok(())
}
