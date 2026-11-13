#pragma once

// Locators for the Linux x86_64 (steamrt64) steamclient.so.
//
// The i386 table in patterns.cpp must never be scanned in a 64-bit module:
// a short i386 byte string can match unrelated x86_64 code and the detour would
// land mid-function.  On x86_64 only the names listed here are scanned; every
// other locator stays unresolved, which a required hook reports as a failed
// load instead of a wrong hook.
//
// Each entry is re-verified offline against the 64-bit client the Steam process
// loads, steamrt64/steamclient.so (make test-patterns-x86_64): exactly one
// match, or several relative call sites converging on one target.  NOTE: that
// is steamrt64/, not linux64/steamclient.so, which is a different binary.
//
// Matching the signature only proves WHERE the function is.  The hook's
// argument list and the SDK structs it touches are validated separately.

#include <cstdint>
#include <string_view>
#include <vector>

namespace PatternsX64
{
	enum class Follow
	{
		None,
		Relative,
		PrologueUpwards,
		// Not a byte signature: slot `slot` of the vtable that `rttiClass` uses
		// for `rttiBase` (see rtti_vtable.hpp), following an adjustor thunk.
		VtableSlot,
		// Not a byte signature: the one function that loads the address of every
		// string in `xrefStrings` (log text and VPROF names are stable across
		// builds).  Entry from .eh_frame_hdr.
		StringXref,
	};

	struct Locator
	{
		std::string_view name;      // Pattern_t::name in patterns.cpp
		std::string_view pattern;
		Follow follow;
		std::vector<int16_t> prologue;

		// VtableSlot only.
		std::string_view rttiClass = {};   // mangled name of the implementing class
		std::string_view rttiBase = {};    // mangled name of the interface base, empty = primary vtable
		int slot = -1;
		// Offline audit only: the IClient*Map proxy class whose slot `slot` must
		// reference the string `methodName`.  This proves the index still names
		// the intended method, which a bare slot number cannot.
		std::string_view mapClass = {};
		std::string_view methodName = {};
		// Which module the locator lives in: steamclient.so (default) or steamui.so.
		bool steamUi = false;
		// Offline audit only: a string the resolved function must reference (a
		// VPROF scope or log text naming it), for slots no IClient*Map covers.
		std::string_view evidence = {};
		// StringXref only.
		std::vector<std::string_view> xrefStrings = {};
		// StringXref only: break a tie between several referencing functions by
		// direct-call count (see RttiVtable::functionReferencingAll).
		bool preferMostCalled = false;
	};

	inline const std::vector<Locator>& locators()
	{
		// Prologue bytes are listed in the order PrologueUpwards reads them,
		// i.e. walking backwards from the match: {55 41 56 41 57 41} is
		// `41 57 41 56 41 55` in memory (push r15; push r14; push r13).
		static const std::vector<Locator> table =
		{
			{ "TraceIPC",
			  "48 89 D7 C1 E8",
			  Follow::PrologueUpwards, { 0x55, 0x41, 0x56, 0x41, 0x57, 0x41 } },
			{ "CSteamEngine::GetServerPipe",
			  "0F B7 CE 31 D2",
			  Follow::PrologueUpwards, { 0x2C, 0x74, 0xF6, 0x85 } },
			{ "CSteamEngine::SetAppIdForCurrentPipe",
			  "0F 43 C6 83 FB",
			  Follow::PrologueUpwards, { 0x55, 0x41, 0x56, 0x41, 0x57, 0x41 } },
			{ "CSteamEngine::ProcessIPCFrame",
			  "48 89 DA 44 89 E6 5B",
			  Follow::PrologueUpwards, { 0xCD, 0x89, 0x49, 0x55, 0x41 } },
			{ "CSteamEngine::m_pUser",
			  "4C 03 A5 ? ? ? ? 48 89 DF 4C 89 E2 E8 ? ? ? ? 49 8B 74 24",
			  Follow::None, {} },
			{ "CUser::CheckAppOwnership",
			  "48 89 E8 31 ED",
			  Follow::PrologueUpwards, { 0xD6, 0x89, 0x49, 0x56, 0x41, 0x57, 0x41 } },
			{ "CUser::PostCallbackToAppId",
			  "44 3B 69 ? 41 89 C5",
			  Follow::PrologueUpwards, { 0x55, 0x41, 0x56, 0x41, 0x57, 0x41 } },
			{ "IClientUtils::m_PipeIndex",
			  "8B B7 ? ? ? ? 64 48 8B 1C 25 ? ? ? ? 48 89 5C 24 ? 48 89 FB 48 81 EF",
			  Follow::None, {} },
			// IPC interface dispatchers: `call <read hash>; mov eax,[rbp-x]; cmp eax,ROOT`
			// at the head of a function that CSteamEngine's interface switch
			// calls on the embedded interface object.  ROOT is the median of the
			// interface's function-hash tree: it drifts a little between client
			// builds and is re-derived at load by autoResolveIpcFrameRoots (seed
			// within 0x10000, or the high-24 pivot fingerprint).  The trailing
			// four bytes MUST stay the root, as for the i386 table.
			{ "IClientAppManager::RunIPCFrame",
			  "E8 ? ? ? ? 8B 85 ? ? ? ? 3D B4 85 0A 7A",
			  Follow::PrologueUpwards, { 0xE5, 0x89, 0x48, 0x55 } },
			{ "IClientApps::RunIPCFrame",
			  "E8 ? ? ? ? 8B 85 ? ? ? ? 3D 33 9C 88 A6",
			  Follow::PrologueUpwards, { 0xE5, 0x89, 0x48, 0x55 } },
			{ "IClientRemoteStorage::RunIPCFrame",
			  "E8 ? ? ? ? 8B 85 ? ? ? ? 3D 5C DD 12 87",
			  Follow::PrologueUpwards, { 0xE5, 0x89, 0x48, 0x55 } },
			{ "IClientUser::RunIPCFrame",
			  "E8 ? ? ? ? 8B 85 ? ? ? ? 3D 83 63 5B 73",
			  Follow::PrologueUpwards, { 0xE5, 0x89, 0x48, 0x55 } },
			{ "IClientUGC::RunIPCFrame",
			  "E8 ? ? ? ? 8B 85 ? ? ? ? 3D 41 0C D2 71",
			  Follow::PrologueUpwards, { 0xE5, 0x89, 0x48, 0x55 } },
			{ "IClientUserStats::RunIPCFrame",
			  "E8 ? ? ? ? 8B 85 ? ? ? ? 3D 62 D6 E5 85",
			  Follow::PrologueUpwards, { 0xE5, 0x89, 0x48, 0x55 } },
			// Same shape as the others on x86_64 (the i386 Utils dispatcher had a
			// different one).  CSteamEngine passes `this+0x1118` -- its IClientUtils
			// base -- to this function from its interface switch.
			{ "IClientUtils::RunIPCFrame",
			  "E8 ? ? ? ? 8B 85 ? ? ? ? 3D 3B EB 7E 7F",
			  Follow::PrologueUpwards, { 0xE5, 0x89, 0x48, 0x55 } },
			// Virtual methods, found through RTTI.  Slot numbers are the method order
			// of the interface, identical on i386 and x86_64 (checked against the
			// IClient*Map proxies by the audit).  IClientUser lives in CUser at a
			// secondary-base offset; its adjustor thunks are followed to the real
			// function, as the i386 signatures did.
			{ "IClientUser::BLoggedOn", "", Follow::VtableSlot, {},
			  "5CUser", "11IClientUser", 4, "14IClientUserMap", "BLoggedOn" },
			{ "IClientUser::BUpdateAppOwnershipTicket", "", Follow::VtableSlot, {},
			  "5CUser", "11IClientUser", 69, "14IClientUserMap", "BUpdateAppOwnershipTicket" },
			{ "IClientUser::RequiresLegacyCDKey", "", Follow::VtableSlot, {},
			  "5CUser", "11IClientUser", 87, "14IClientUserMap", "RequiresLegacyCDKey" },
			{ "IClientUser::GetAppOwnershipTicketExtendedData", "", Follow::VtableSlot, {},
			  "5CUser", "11IClientUser", 106, "14IClientUserMap", "GetAppOwnershipTicketExtendedData" },
			{ "IClientUser::IsUserSubscribedAppInTicket", "", Follow::VtableSlot, {},
			  "5CUser", "11IClientUser", 119, "14IClientUserMap", "IsUserSubscribedAppInTicket" },
			{ "CUser::GetSubscribedApps", "", Follow::VtableSlot, {},
			  "5CUser", "11IClientUser", 183, "14IClientUserMap", "GetSubscribedApps" },
			{ "IClientAppManager::BCanRemotePlayTogether", "", Follow::VtableSlot, {},
			  "15CUserAppManager", "", 73, "20IClientAppManagerMap", "BCanRemotePlayTogether" },
			{ "IClientFriends::GetFriendGamePlayed", "", Follow::VtableSlot, {},
			  "12CUserFriends", "14IClientFriends", 23, "17IClientFriendsMap", "GetFriendGamePlayed" },
			// ISteamMatchmakingServers order: RequestInternetServerList = 0, GetServerDetails = 7.
			{ "CSteamMatchmakingServers::RequestInternetServerList", "", Follow::VtableSlot, {},
			  "24CSteamMatchMakingServers", "", 0 },
			{ "CSteamMatchmakingServers::GetServerDetails", "", Follow::VtableSlot, {},
			  "24CSteamMatchMakingServers", "", 7 },
			// Plain functions, same bytes as AceSLS/SLSsteam; both are called, not
			// hooked, by Moon with the same argument shapes as SLSsteam's calls.
			{ "CSteamEngine::PostCallback",
			  "E8 ? ? ? ? 4D 8B AE",
			  Follow::Relative, {} },
			{ "IClientUser::UpdateAppOwnershipTicket",
			  "41 89 CD 83 FD",
			  Follow::PrologueUpwards, { 0x55, 0x41, 0x56, 0x41, 0x57, 0x41 } },
			// steamui.so.  The ping-response interface is the base of CGameInfoDialog
			// at +8; its slot 0 is an adjustor thunk to the real ServerResponded.
			{ "ISteamMatchmakingPingResponse::ServerResponded", "", Follow::VtableSlot, {},
			  "15CGameInfoDialog", "29ISteamMatchmakingPingResponse", 0, {}, {}, true },
			// CRemoteClientManager's primary vtable: slot 3 references its own VPROF
			// scope name "CRemoteClientManager::RecvPkt".
			{ "CRemoteClientManager::RecvPkt", "", Follow::VtableSlot, {},
			  "20CRemoteClientManager", "", 3, {}, {}, false, "CRemoteClientManager::RecvPkt" },
			// Family Share filter (optional).  Slot 3 of CCMInterface is the CM message
			// handler SLSsteam hooks; the evidence string is weaker than the one above.
			{ "CCMInterface::RecvPkt", "", Follow::VtableSlot, {},
			  "12CCMInterface", "", 3, {}, {}, false, "23LegacyCDKeyRegistered_t" },
			// Located by its own log lines: both strings are loaded by this one function.
			{ "CDepotDownloadMgr::BYldRequestDepotManifest", "", Follow::StringXref, {},
			  "", "", -1, {}, {}, false, {},
			  { "CDepotDownloadMgr::BYldRequestDepotManifest(App: %d, Depot: %d, Manifest: %llu, branch: %s): Failed to get manifest request code, '%s'",
			    "CDepotDownloadMgr::BYldRequestDepotManifest: same manifest %llu requested twice" } },
			// CJobMgr::BRouteMsgToJob carries two VPROF scopes, one per routing path.
			{ "CJobMgr::BRouteMsgToJob", "", Follow::StringXref, {},
			  "", "", -1, {}, {}, false, {},
			  { "CJobMgr::BRouteMsgToJob() - continue job", "CJobMgr::BRouteMsgToJob() - job" } },
			// Three overloads share the "InitFromPacket" VPROF scope (a plain one, one
			// that frees the previous body, and a devirtualising wrapper).  The one Moon
			// hooks is the public entry: 170 call sites on both i386 and x86_64, the
			// others are reached through the vtable or one wrapper.
			{ "CProtoBufMsgBase::InitFromPacket", "", Follow::StringXref, {},
			  "", "", -1, {}, {}, false, {},
			  { "CProtoBufMsg::InitFromPacket( IMsgNetPacket )" }, true },
			// Serialized size of a message (header + body, +8): `call [rax+0x48]` then
			// `lea eax,[rax+rbp+8]`.  Same shape and same two callers as the i386 function.
			{ "CProtoBufMsgBase::Send",
			  "FF 50 48 8D 44 28 08 48 83 C4 08 5B 5D C3",
			  Follow::PrologueUpwards, { 0xFB, 0x89, 0x48, 0x53, 0x55 } },
			{ "CWebSocketConnection::BBuildAndAsyncSendFrame",
			  "45 31 F6 83 7F",
			  Follow::PrologueUpwards, { 0x55, 0x41, 0x56, 0x41, 0x57, 0x41 } },
		};
		return table;
	}

	inline const Locator* find(std::string_view name)
	{
		for (const auto& locator : locators())
		{
			if (locator.name == name)
				return &locator;
		}
		return nullptr;
	}
}
