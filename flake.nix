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

      makeCheck = packageToTest: lua: flakePkgs.nixosTest {
        name = "test-${packageToTest.name}";
        nodes.machine = { pkgs, lib, ... }: {

          virtualisation.writableStore = true;
          nix.binaryCaches = lib.mkForce [ ]; # no network

          nixpkgs.overlays = [

            (this: super: {

              dbus_proxy_tests = pkgs.stdenv.mkDerivation {
                name = "dbus_proxy_tests";
                src = ./.;
                buildPhase = ":";
                installPhase = "mkdir -p $out/tests && cp -r tests/ $out/tests/";
                doCheck = false;
              };

              dbus_proxy_app = lua.withPackages (ps: [
                packageToTest
              ] ++ packageToTest.buildInputs);
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

      overlay = final: prev: {
        # TODO: can I add these to the main luaPackages in nixpkgs?
        extraLua52Packages.dbus_proxy = self.packages.x86_64-linux.lua52_dbus_proxy;
        extraLua53Packages.dbus_proxy = self.packages.x86_64-linux.lua53_dbus_proxy;
        extraLuaJitPackages.dbus_proxy = self.packages.x86_64-linux.luajit_dbus_proxy;
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
        lua52Check = makeCheck self.packages.x86_64-linux.lua52_dbus_proxy flakePkgs.lua5_2;
        lua53Check = makeCheck self.packages.x86_64-linux.lua53_dbus_proxy flakePkgs.lua5_3;
        luajitCheck = makeCheck self.packages.x86_64-linux.luajit_dbus_proxy flakePkgs.luajit;
      };

    };
}
