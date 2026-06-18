{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		sushy-lib = {
			url = "github:sushydev/nix-lib";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { self, nixpkgs, sushy-lib }: {
		devShells = sushy-lib.forPlatforms sushy-lib.platforms.default (system:
			let
				pkgs = import nixpkgs { inherit system; };
			in
			{
				default = pkgs.mkShell {
					buildInputs = [
						pkgs.beamMinimal28Packages.elixir_1_19
						pkgs.beamMinimal28Packages.expert
						#pkgs.watchman
						#pkgs.inotify-tools
						pkgs.sqlite
						pkgs.mkcert
						#pkgs.nss.tools  # provides certutil for SSL certificate management
						pkgs.jq

						pkgs.postgresql
						pkgs.pgcli
					];

					shellHook = ''
						echo "Elixir version: $(elixir --version)"

						# Setup isolated environment variables
						export PGDATA="$PWD/.direnv/postgres_data"
						export PGHOST="$PGDATA"

						# Initialize PostgreSQL database if it doesn't exist yet
						if [ ! -d "$PGDATA" ]; then
							initdb -D "$PGDATA" --auth=trust --no-locale --encoding=UTF8
							
							# Update these lines to allow TCP connections on localhost
							echo "listen_addresses = '127.0.0.1'" >> "$PGDATA/postgresql.conf"
							echo "port = 5432" >> "$PGDATA/postgresql.conf"
							echo "unix_socket_directories = '$PGDATA'" >> "$PGDATA/postgresql.conf"
						fi

						echo ""
						echo "🐘 PostgreSQL environment loaded."
						echo "  Start server: pg_ctl start -l $PGDATA/server.log"
						echo "  Stop server:  pg_ctl stop"
						echo "  Connect:      psql postgres"
						echo ""
					'';
				};
			}
		);

		apps = sushy-lib.forPlatforms sushy-lib.platforms.default (system:
			let
				pkgs = import nixpkgs { inherit system; };
			in
			{
				webserver = {
					name = "webserver";
					type = "app";
					program = "${pkgs.writeShellScript "webserver" ''
						mix phx.server > /tmp/phx.log 2>&1 &
						tail -f /tmp/phx.log
					''}";
				};
			}
		);
	};
}
