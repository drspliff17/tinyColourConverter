package main

import fmt "core:fmt"
import os "core:os"
import st "core:strings"

Prompt_Return :: enum {
	Positive,
	Negative,
	InvalidInput,
}

// Simple In/Out prompt, displays given string, returns user input data
genericPrompt :: proc(display_msg: string) -> string {

	fmt.print(display_msg)
	buf: [1]u8
	out: [256]u8
	i := 0

	for {
		n, err := os.read(os.stdin, buf[:])
		if err != nil || n == 0 {
			break
		}

		if buf[0] == '\n' {
			break
		}

		if i < len(out) {
			out[i] = buf[0]
			i += 1
		}
	}


	return string(out[:i])
}

/*Extends genericPrompt, checks if input is within positive/negative overrides (if set), or defaults [y/yes - n/no] (case insensitive)

Optionally, can also set treat_invalid_as_negative, to prevent returning Prompt_Return.InvalidInput, when input does not match 
p_valid or n_valid
*/
confirmationPrompt :: proc(
	display_msg: string,
	treat_invalid_as_negative: bool,
	p_override: []string = {},
	n_override: []string = {},
) -> Prompt_Return {

	fmt.print(display_msg)
	buf: [1]u8
	out: [256]u8
	i := 0

	for {
		n, err := os.read(os.stdin, buf[:])
		if err != nil || n == 0 {
			break
		}

		if buf[0] == '\n' {
			break
		}

		if i < len(out) {
			out[i] = buf[0]
			i += 1
		}
	}

	p_valid := []string{"y", "yes"}
	if len(p_override) != 0 do p_valid = p_override

	n_valid := []string{"n", "no"}
	if len(n_override) != 0 do n_valid = n_override

	input := string(out[:i])
	input = st.to_lower(input, context.allocator)
	for pk in p_valid {
		if input == pk do return .Positive
	}

	for nk in n_valid {
		if input == nk do return .Negative
	}

	if treat_invalid_as_negative do return .Negative

	return .InvalidInput
}
