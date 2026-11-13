// DetourX64 on synthetic functions placed far from the hook: the trampoline must execute
// the displaced instructions correctly (RIP-relative load, rel8 jcc, call rel32) and
// remove() must restore the original bytes.  Links libmem only.
#include "detour_x64.hpp"

#include <sys/mman.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

static int failures = 0;
static void expect(bool ok, const std::string& text)
{
	std::printf("%s: %s\n", ok ? "ok" : "FAIL", text.c_str());
	if (!ok)
		++failures;
}

extern "C" std::uint64_t hookValue(std::uint64_t) { return 0x1111; }

using Fn = std::uint64_t (*)(std::uint64_t);

int main()
{
	std::uint8_t* page = static_cast<std::uint8_t*>(
		mmap(reinterpret_cast<void*>(0x7d0000000000ull), 0x4000, PROT_READ | PROT_WRITE | PROT_EXEC,
		     MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0));
	if (page == MAP_FAILED)
	{
		std::puts("cannot map the test page");
		return 2;
	}
	const auto hook = reinterpret_cast<lm_address_t>(&hookValue);
	std::printf("hook at %p, code page at %p\n", reinterpret_cast<void*>(hook), static_cast<void*>(page));

	// 1. RIP-relative load in the displaced bytes.
	{
		std::uint64_t* data = reinterpret_cast<std::uint64_t*>(page + 0x1000);
		*data = 0xDEADBEEFCAFEull;
		std::uint8_t* fn = page + 0x100;
		const std::int32_t disp = static_cast<std::int32_t>(reinterpret_cast<std::uint8_t*>(data) - (fn + 7));
		const std::uint8_t code[] = {0x48, 0x8B, 0x05, 0, 0, 0, 0, 0x90, 0x90, 0x90, 0x90, 0x90, 0xC3};
		std::memcpy(fn, code, sizeof(code));
		std::memcpy(fn + 3, &disp, 4);
		expect(reinterpret_cast<Fn>(fn)(0) == 0xDEADBEEFCAFEull, "rip: original reads the data");
		std::string error;
		const auto placed = DetourX64::place(reinterpret_cast<lm_address_t>(fn), hook, &error);
		expect(placed.has_value(), "rip: placed " + error);
		if (placed)
		{
			const std::int64_t distance = static_cast<std::int64_t>(placed->trampoline) - reinterpret_cast<std::int64_t>(fn);
			expect(distance > -0x7FFF0000ll && distance < 0x7FFF0000ll, "rip: trampoline within 2 GiB of the target");
			expect(reinterpret_cast<Fn>(fn)(0) == 0x1111, "rip: hook runs through the detour");
			expect(reinterpret_cast<Fn>(placed->trampoline)(0) == 0xDEADBEEFCAFEull, "rip: trampoline still reads the data");
			expect(DetourX64::remove(reinterpret_cast<lm_address_t>(fn)), "rip: removed");
			expect(reinterpret_cast<Fn>(fn)(0) == 0xDEADBEEFCAFEull, "rip: original restored");
		}
	}

	// 2. rel8 jne inside the displaced bytes (widened in the trampoline).
	{
		std::uint8_t* fn = page + 0x200;
		const std::uint8_t code[] = {
			0x48, 0x85, 0xFF,             // test rdi,rdi
			0x75, 0x06,                   // jne +6  -> L
			0xB8, 0x01, 0, 0, 0,          // mov eax,1
			0xC3,                         // ret
			0xB8, 0x02, 0, 0, 0,          // L: mov eax,2
			0xC3};
		std::memcpy(fn, code, sizeof(code));
		expect(reinterpret_cast<Fn>(fn)(0) == 1 && reinterpret_cast<Fn>(fn)(1) == 2, "jcc: original branches");
		std::string error;
		const auto placed = DetourX64::place(reinterpret_cast<lm_address_t>(fn), hook, &error);
		expect(placed.has_value(), "jcc: placed " + error);
		if (placed)
		{
			expect(reinterpret_cast<Fn>(placed->trampoline)(0) == 1, "jcc: trampoline falls through");
			expect(reinterpret_cast<Fn>(placed->trampoline)(1) == 2, "jcc: trampoline takes the branch");
			DetourX64::remove(reinterpret_cast<lm_address_t>(fn));
			expect(reinterpret_cast<Fn>(fn)(1) == 2, "jcc: original restored");
		}
	}

	// 3. call rel32 inside the displaced bytes.
	{
		std::uint8_t* helper = page + 0x380;
		const std::uint8_t helperCode[] = {0xB8, 0x07, 0, 0, 0, 0xC3};
		std::memcpy(helper, helperCode, sizeof(helperCode));
		std::uint8_t* fn = page + 0x300;
		const std::int32_t rel = static_cast<std::int32_t>(helper - (fn + 4 + 5));
		const std::uint8_t code[] = {0x48, 0x83, 0xEC, 0x08, 0xE8, 0, 0, 0, 0, 0x48, 0x83, 0xC4, 0x08, 0xC3};
		std::memcpy(fn, code, sizeof(code));
		std::memcpy(fn + 5, &rel, 4);
		expect(reinterpret_cast<Fn>(fn)(0) == 7, "call: original");
		std::string error;
		const auto placed = DetourX64::place(reinterpret_cast<lm_address_t>(fn), hook, &error);
		expect(placed.has_value(), "call: placed " + error);
		if (placed)
		{
			expect(reinterpret_cast<Fn>(placed->trampoline)(0) == 7, "call: trampoline reaches the helper");
			DetourX64::remove(reinterpret_cast<lm_address_t>(fn));
		}
	}

	// 4. A prologue that cannot be relocated is refused and left untouched.
	{
		std::uint8_t* fn = page + 0x400;
		const std::uint8_t code[] = {0xE3, 0x02, 0x90, 0x90, 0x90, 0x90, 0xC3}; // jrcxz +2
		std::memcpy(fn, code, sizeof(code));
		std::uint8_t before[sizeof(code)];
		std::memcpy(before, fn, sizeof(code));
		std::string error;
		const auto placed = DetourX64::place(reinterpret_cast<lm_address_t>(fn), hook, &error);
		expect(!placed.has_value(), "refuse: jrcxz cannot be relocated (" + error + ")");
		expect(std::memcmp(before, fn, sizeof(code)) == 0, "refuse: target bytes untouched");
	}

	return failures == 0 ? 0 : 1;
}
