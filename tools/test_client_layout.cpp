// ClientLayout::clientDirectory must follow steam.sh: SteamRT 64-bit client by default,
// legacy ubuntu12_32 behind the sentinel or STEAM_FORCE_CLIENT.
#include "pattern-refresh/client_layout.hpp"

#include <cstdio>
#include <fstream>

namespace fs = std::filesystem;
static int failures = 0;

static void expect(bool ok, const char* text)
{
	std::printf("%s: %s\n", ok ? "ok" : "FAIL", text);
	if (!ok)
		++failures;
}

int main()
{
	const fs::path root = fs::temp_directory_path() / "slsm-client-layout-test";
	fs::remove_all(root);
	fs::create_directories(root / "steamrt64");
	fs::create_directories(root / "ubuntu12_32");
	{ std::ofstream(root / "steamrt64/steamclient.so"); }
	{ std::ofstream(root / "steamrt64/steam") << "#!/bin/sh\n"; }

	// steamrt64/steam is not executable yet
	expect(ClientLayout::clientDirectory(root, "") == root / "ubuntu12_32", "no executable launcher: legacy");
	fs::permissions(root / "steamrt64/steam", fs::perms::owner_exec, fs::perm_options::add);
	expect(ClientLayout::clientDirectory(root, "") == root / "steamrt64", "64-bit client by default");
	expect(ClientLayout::clientDirectory(root, "scout") == root / "ubuntu12_32", "STEAM_FORCE_CLIENT=scout");
	expect(ClientLayout::clientDirectory(root, "ldlp") == root / "ubuntu12_32", "STEAM_FORCE_CLIENT=ldlp");

	{ std::ofstream(root / ".steam-disable-steamrt64-client"); }
	expect(ClientLayout::clientDirectory(root, "") == root / "ubuntu12_32", "disable sentinel");
	expect(ClientLayout::clientDirectory(root, "steamrt3c") == root / "steamrt64", "force steamrt3c beats the sentinel");
	expect(ClientLayout::clientDirectory(root, "unknown") == root / "ubuntu12_32", "unknown value keeps the sentinel");

	fs::remove_all(root);
	return failures == 0 ? 0 : 1;
}
