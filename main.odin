package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:strconv"
import st "core:strings"
import "core:unicode"
import rl "vendor:raylib"

// Conversion Procs

HexToRgb :: proc(hex: string) -> (u8, u8, u8, bool) {
	h := hex

	if len(h) == 0 {
		return 0, 0, 0, false
	}

	if h[0] == '#' {
		h = h[1:]
	}

	if len(h) != 6 {
		return 0, 0, 0, false
	}

	hex_nibble :: proc(c: u8) -> (u8, bool) {
		switch {
		case c >= '0' && c <= '9':
			return c - '0', true
		case c >= 'a' && c <= 'f':
			return 10 + (c - 'a'), true
		case c >= 'A' && c <= 'F':
			return 10 + (c - 'A'), true
		}
		return 0, false
	}

	byte :: proc(a, b: u8) -> (u8, bool) {
		hi, ok1 := hex_nibble(a)
		lo, ok2 := hex_nibble(b)
		if !ok1 || !ok2 {
			return 0, false
		}
		return (hi << 4) | lo, true
	}

	r, ok1 := byte(h[0], h[1])
	g, ok2 := byte(h[2], h[3])
	b, ok3 := byte(h[4], h[5])

	if !ok1 || !ok2 || !ok3 {
		return 0, 0, 0, false
	}

	return r, g, b, true
}

RgbToRL :: proc(c: string) -> rl.Color {
	parts := st.split(c, ",", context.allocator)
	if len(parts) != 3 {
		return {0, 0, 0, 0}
	}

	r64, _ := strconv.parse_int(st.trim_space(parts[0]))
	g64, _ := strconv.parse_int(st.trim_space(parts[1]))
	b64, _ := strconv.parse_int(st.trim_space(parts[2]))

	return rl.Color{u8(r64), u8(g64), u8(b64), 255}
}

ColorToInt :: proc(col: rl.Color) -> c.int {
	return c.int(col.r) << 24 | c.int(col.g) << 16 | c.int(col.b) << 8 | c.int(col.a)
}

RgbToHex :: proc(r, g, b: u8) -> u32 {
	return (u32(r) << 16) | (u32(g) << 8) | u32(b)
}


// Populates Entry struct from given string, using Conversion procs
ParseString :: proc(c: string, e: ^Entry) -> bool {
	if len(c) > 0 && c[0] == '#' {
		r, g, b, ok := HexToRgb(c)
		if !ok {
			return false
		}

		e.r = r
		e.g = g
		e.b = b
	} else {
		parts := st.split(c, ",", context.allocator)
		if len(parts) != 3 {
			return false
		}

		r64, _ := strconv.parse_int(st.trim_space(parts[0]))
		g64, _ := strconv.parse_int(st.trim_space(parts[1]))
		b64, _ := strconv.parse_int(st.trim_space(parts[2]))

		e.r = u8(r64)
		e.g = u8(g64)
		e.b = u8(b64)
	}

	e.rlc = rl.Color{e.r, e.g, e.b, 255}
	e.cic = ColorToInt(e.rlc)
	e.hex = RgbToHex(e.r, e.g, e.b)
	e.fhex = fmt.tprintf("#%06X", e.hex)

	return true
}

// Return string value of target value
GetEntryValue :: proc(e: ^Entry, v: RT) -> string {
	#partial switch v {
	case .INT:
		return fmt.tprintf("%d", e.cic)

	case .HEX:
		return fmt.tprint("%d", e.hex) //fmt.tprintf("#%06X", e.hex)

	case .FORMATTED_HEX:
		return e.fhex

	case .ALL:
		return fmt.tprintf(
			"Entry r = %d, g = %d, b = %d, int = %d, hex = %d, fhex = %s ",
			e.r,
			e.g,
			e.b,
			e.cic,
			e.hex,
			e.fhex,
		)

	case:
		return ""
	}
}

// No Safety Checks on notification ext arguments
Notify :: proc(msg: string, appname := "center-text", urgency := "low", time := "3000") {
	if os.is_tty(os.stdin) {
		fmt.println(msg)
	} else {
		pargs := []string{"notify-send", "-a", appname, "-u", urgency, "-t", time, msg}

		procDesc := os.Process_Desc {
			command = pargs,
		}
		_, _, _, perr := os.process_exec(procDesc, context.allocator)
		if perr != nil do fmt.panicf("Failed to notify, what the helly?: %v", perr)
	}
}

DumpValue :: proc(filepath, value: string) {
	home, _ := os.user_home_dir(context.allocator)
	defer delete_string(home)

	if !st.starts_with(filepath, home) {
		filepath, _ := os.join_path([]string{home, filepath}, context.allocator)
		defer delete_string(filepath)
	}

	if os.exists(filepath) {
		p := confirmationPrompt(
			fmt.tprintf(
				"File already exists at: %s - Do you want to overwrite it? [Y/n]: ",
				filepath,
			),
			true,
		)
		if p != .Positive {
			fmt.println("[ABORTED]")
			os.exit(0)
		}
		rm_err := os.remove(filepath)
		if rm_err != nil do fmt.panicf("Failed to remove: %s : %v", filepath, rm_err)
	}

	file, ferr := os.create(filepath)
	defer os.close(file)
	if ferr != nil do fmt.panicf("Failed to create: %s : %v", filepath, ferr)

	werr := os.write_entire_file(filepath, value)
	if werr != nil do fmt.panicf("Failed to write: %s : %v", filepath, werr)
}

RGB_ValidateValue :: proc(value: string) -> bool {
	if len(value) == 0 do return false

	split, serr := st.split(value, ",", context.allocator)
	defer delete_slice(split)
	if serr != nil do return false

	if len(split) < 3 {
		fmt.eprintln("[ERROR] Expected 3 values, got: ", len(split))
		return false
	}
	for c in split {
		for r in c {
			if !unicode.is_digit(r) do return false
		}
	}
	return true
}

// Determines what happens with the output data
Actions :: enum {
	NONE,
	NOTIFY,
	DUMP,
}

// Determines what element of the Entry gets outputted
RT :: enum {
	NONE,
	INT,
	HEX,
	FORMATTED_HEX,
	ALL,
}

// Internal state
State :: struct {
	action: Actions,
	rt:     RT,
	dump:   string,
}

// Conversion data from RGB input arguments
Entry :: struct {
	r:    u8,
	g:    u8,
	b:    u8,
	r64:  int,
	g64:  int,
	b64:  int,
	cic:  c.int,
	hex:  u32,
	fhex: string,
	rlc:  rl.Color,
}

SKIP_ARGCHECK: bool


main :: proc() {
	args := os.args[1:]

	switch (len(args)) {
	case 0:
		fmt.eprintln("Invalid Usage: Provide RGB Value to convert (CSV)")
		os.exit(1)
	case 1:
		SKIP_ARGCHECK = true
	}

	s := State{}
	if !SKIP_ARGCHECK {
		argcheck: for len(args) > 0 {
			switch (args[0]) {

			case "-d", "--dump":
				s.action = .DUMP

				p := confirmationPrompt(
					fmt.tprintf("[CONFIRM] Dump to: %s? [Y/n]: ", args[1]),
					true,
				)
				if p != .Positive {
					fmt.println("[ABORTED]")
					os.exit(0)
				}

				s.dump = args[1]
				args = args[2:]

			case "-x", "--hex":
				s.rt = .HEX
				args = args[1:]

			case "-fx", "--fhex":
				s.rt = .FORMATTED_HEX
				args = args[1:]

			case "-i", "--int":
				s.rt = .INT
				args = args[1:]

			case "-e", "--entries":
				args = args[1:]
				break argcheck

			case:
				fmt.eprintfln("Invalid Argument: %s", args[0])
				os.exit(1)

			}
		}
	}

	if s.action == .NONE do s.action = .NOTIFY
	if s.rt == .NONE do s.rt = .ALL

	EntryMap := make([dynamic]Entry)
	defer delete(EntryMap)

	outstr := ""
	defer delete_string(outstr)

	for e in args {
		//NOTE: Make this have a HEX validate too
		if !st.starts_with(e, "#") {
			if !RGB_ValidateValue(e) {
				fmt.eprintfln("Invalid RGB Value: %s", e)
				continue
			}
		}

		new := Entry{}
		ParseString(e, &new)
		append(&EntryMap, new)
	}

	for i := 0; i < len(EntryMap); i += 1 {
		e := EntryMap[i]
		value := GetEntryValue(&e, s.rt)
		if value == "" do panic("Unable to get value!")

		#partial switch (s.action) {
		case .NOTIFY:
			Notify(value)

		case .DUMP:
			outstr = st.join([]string{outstr, value}, "\n", context.allocator)
		}
	}

	if s.action == .DUMP {
		DumpValue(s.dump, outstr)
	}

}
