use std::env;
use std::process::exit;

fn main() {
    let command = env::args().nth(1);

    match command.as_deref() {
        Some("hello") => println!("world"),
        Some("ping") => println!("pong"),
        Some("--version") => println!("{}", env!("CARGO_PKG_VERSION")),
        _ => {
            eprintln!("Usage: bitloops <hello|ping|--version>");
            exit(1);
        }
    }
}
