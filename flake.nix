{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }:
    let
      flakePkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
      };

      buildPackage = luaPackages: with luaPackages;
        buildLuaPackage rec {
          name = "${pname}-${version}";
          pname = "dbus_proxy";
          version = "${self.lastModifiedDate}-${self.shortRev or "dev"}";

          src = ./.;

          propagatedBuildInputs = [ lua lgi ];

          buildInputs = [ busted luacov ldoc ];

          buildPhase = ":";

          installPhase = ''
            mkdir -p "$out/share/lua/${lua.luaversion}"
            cp -r src/${pname} "$out/share/lua/${lua.luaversion}/"
          '';

          doCheck = false; # see flake checks
          checkPhase = "busted .";

        };

      makeCheck = lua: flakePkgs.nixosTest {
        name = lua.pkgs.dbus_proxy.name;
        nodes.machine = { pkgs, lib, ... }: {

          virtualisation.writableStore = true;
          nix.binaryCaches = lib.mkForce [ ]; # no network

          nixpkgs.overlays = [

            self.overlay

            (this: super: {

              dbus_proxy_tests = pkgs.stdenv.mkDerivation {
                name = "dbus_proxy_tests";
                src = ./.;
                buildPhase = ":";
                installPhase = "mkdir -p $out/tests && cp -r tests/ $out/tests/";
                doCheck = false;
              };

              dbus_proxy_app = lua.withPackages (ps: [
                ps.dbus_proxy
              ] ++ lua.pkgs.dbus_proxy.buildInputs);
            })

          ];

          environment.variables = {
            LUA_DBUS_PROXY_TESTS_PATH = "${pkgs.dbus_proxy_tests}";
          };

          users.users.test-user = {
            isNormalUser = true;
            shell = pkgs.bashInteractive;
            password = "just-A-pass";
            home = "/home/test-user";
            packages = [ pkgs.dbus_proxy_app ];
          };

        };

        testScript = ''
          # To use DBus properly, login and execute the test suite.
          # strategy taken from nixos/tests/login.nix
          machine.wait_for_unit("multi-user.target")
          machine.wait_until_tty_matches(1, "login: ")
          machine.send_chars("test-user\n")
          machine.wait_until_tty_matches(1, "login: test-user")
          machine.wait_until_succeeds("pgrep login")
          machine.wait_until_tty_matches(1, "Password: ")
          machine.send_chars("just-A-pass\n")
          machine.wait_until_succeeds("pgrep -u test-user bash")
          machine.send_chars("busted $LUA_DBUS_PROXY_TESTS_PATH > output\n")
          machine.wait_for_file("/home/test-user/output")
          machine.send_chars("echo $? > result\n")
          machine.wait_for_file("/home/test-user/result")
          output = machine.succeed("cat /home/test-user/output")
          result = machine.succeed("cat /home/test-user/result")
          assert result == "0\n", "Test suite failed: {}".format(output)
        '';

      };

    in
    {
      defaultPackage.x86_64-linux = self.packages.x86_64-linux.lua52_dbus_proxy;

      packages.x86_64-linux = {
        lua52_dbus_proxy = buildPackage flakePkgs.lua52Packages;
        lua53_dbus_proxy = buildPackage flakePkgs.lua53Packages;
        luajit_dbus_proxy = buildPackage flakePkgs.luajitPackages;
      };

      overlay = final: prev: with self.packages.x86_64-linux; {
        lua5_2 = prev.lua5_2.override {
          packageOverrides = this: other: {
            dbus_proxy = lua52_dbus_proxy;
          };
        };

        lua5_3 = prev.lua5_3.override {
          packageOverrides = this: other: {
            dbus_proxy = lua53_dbus_proxy;
          };
        };

        luajit = prev.luajit.override {
          packageOverrides = this: other: {
            dbus_proxy = luajit_dbus_proxy;
          };
        };
      };

      devShell.x86_64-linux = flakePkgs.mkShell {
        LUA_PATH = "./src/?.lua;./src/?/init.lua";
        buildInputs = (with self.defaultPackage.x86_64-linux; buildInputs ++ propagatedBuildInputs) ++ (with flakePkgs; [
          nixpkgs-fmt
        ]);
      };

      # https://nixos.org/manual/nixos/stable/index.html#sec-running-nixos-tests-interactively
      # nix build '.#checks.x86_64-linux.<name>.driverInteractive'
      # ./result/bin/nixos-run-vms # to start the VM
      # ./result/bin/nixos-test-driver # to start the Pyton test shell
      checks.x86_64-linux = {
        lua52Check = makeCheck flakePkgs.lua5_2;
        lua53Check = makeCheck flakePkgs.lua5_3;
        luajitCheck = makeCheck flakePkgs.luajit;
      };

    };
}
