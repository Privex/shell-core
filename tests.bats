#!/usr/bin/env bats

load $PWD/load.sh

fail_print() { >&3 echo -n $'\n# ------------\n'; >&3 echo "# [FAIL] $@" $'\n'; return 1; }

#### core_func.len
#### len() outputs the number of characters in the passed string(s)

@test "test len() outputs 0 for '' (empty string)" {
    run len ""
    [ "$status" -eq 0 ]
    # echo "len of '' is: $output" >&3
    ((output==0)) || fail_print "len of '' is: $output"
}

@test "test len() outputs 5 for 'hello'" {
    run len "hello"
    [ "$status" -eq 0 ]
    ((output==5)) || fail_print "len of 'hello' is: $output"
}

@test "test len() outputs 11 for 'hello' 'world' (should expand to 'hello world')" {
    run len "hello" "world"
    [ "$status" -eq 0 ]
    # echo "len of 'hello' 'world' is: $output" >&3
    ((output==11)) || fail_print "len of 'hello' 'world' is: $output"
}

@test "test len() outputs 11 for \$'hello\\nworld' (newlines should count as 1 char)" {
    run len $'hello\nworld'
    # echo "len of 'hello\\nworld' is: $output" >&3
    [ "$status" -eq 0 ]
    ((output==11)) || fail_print "len of 'hello\\nworld' is: $output"
}


#### core_func.has_binary
#### has_binary should return 0 only for existant binaries on disk. NOT functions / aliases.

example_test_func() { echo "hello world"; }


@test "test has_binary returns zero with existant binary (ls)" {
    run has_binary ls
    [ "$status" -eq 0 ]
}

@test "test has_binary returns non-zero with non-existant binary (thisbinaryshouldnotexit)" {
    run has_binary thisbinaryshouldnotexit
    [ "$status" -eq 1 ]
}

@test "test has_binary returns non-zero for existing function but non-existant binary (example_test_func)" {
    run has_binary example_test_func
    [ "$status" -eq 1 ]
}

#### core_func.has_command
#### has_command should return 0 for both existing functions and existing binaries on disk

@test "test has_command returns zero for existing function but non-existant binary (example_test_func)" {
    run has_command example_test_func
    [ "$status" -eq 0 ]
}

@test "test has_command returns zero for non-existing function but existant binary (ls)" {
    run has_command example_test_func
    [ "$status" -eq 0 ]
}

@test "test has_command returns non-zero for non-existing function and non-existant binary (thisbinaryshouldnotexit)" {
    run has_command thisbinaryshouldnotexit
    [ "$status" -eq 1 ]
}

### helpers.split_by


@test "test split_by by splitting 'hello:world:test' on char ':'" {
    run split_by "hello:world:test" ":"
    [ "$status" -eq 0 ]
    data=($output)
    [ "${data[0]}" == "hello" ] || fail_print "data[0] is: ${data[0]}"
    [ "${data[1]}" == "world" ] || fail_print "data[1] is: ${data[1]}"
    [ "${data[2]}" == "test" ] || fail_print "data[2] is: ${data[2]}"
}

@test "test split_by by splitting 'hello:world,testing:orange' on char ','" {
    run split_by 'hello:world,testing:orange' ","
    [ "$status" -eq 0 ]
    data=($output)
    [ "${data[0]}" == "hello:world" ] || fail_print "data[0] is: ${data[0]}"
    [ "${data[1]}" == "testing:orange" ] || fail_print "data[1] is: ${data[1]}"
}

@test "test split_by returns 1 with error if not enough args [1 args]" {
    run split_by "hello:world:test"
    [ "$status" -eq 1 ]
    [ "$output" = "Error: split_by requires exactly 2 arguments" ]
}

@test "test split_by returns 1 with error if not enough args [3 args]" {
    run split_by "hello:world:test" "," ":"
    [ "$status" -eq 1 ]
    [ "$output" = "Error: split_by requires exactly 2 arguments" ]
}

### helpers.split_assoc

@test "test split_assoc by splitting 'hello:world,testing:orange' on char ',' and ':'" {
    run split_assoc 'hello:world,testing:orange' "," ":"
    [ "$status" -eq 0 ]
    source "$output"
    [ "${assoc_result[hello]}" == "world" ] || fail_print "assoc_result[hello] is: ${assoc_result[hello]}"
    [ "${assoc_result[testing]}" == "orange" ] || fail_print "assoc_result[testing] is: ${assoc_result[testing]}"
}

@test "test split_assoc by splitting 'hello=world;testing=orange' on char ';' and '='" {
    run split_assoc 'hello=world;testing=orange' ";" "="
    [ "$status" -eq 0 ]
    source "$output"
    [ "${assoc_result[hello]}" == "world" ]
    [ "${assoc_result[testing]}" == "orange" ]
}


@test "test split_assoc returns 1 with error if not enough args [2 args]" {
    run split_assoc 'hello=world;testing=orange' ";"
    [ "$status" -eq 1 ]
    [ "$output" = "Error: split_assoc requires exactly 3 arguments" ]    
}

@test "test split_assoc returns 1 with error if not enough args [4 args]" {
    run split_assoc 'hello=world;testing=orange' ";" "," "/"
    [ "$status" -eq 1 ]
    [ "$output" = "Error: split_assoc requires exactly 3 arguments" ]    
}

### helpers.containsElement

test_array=(hello world example)

@test "test containsElement returns 0 if array contains specified element" {
    run containsElement "world" "${test_array[@]}"
    [ "$status" -eq 0 ]
}

@test "test containsElement returns 1 if array does not contain specified element" {
    run containsElement "orange" "${test_array[@]}"
    [ "$status" -eq 1 ]
}

### trap_helper.trap_add / get_trap_cmd

_tst_get_trap() { get_trap_cmd "$1" | tr -s '\n'; }

@test "test trap_add+get_trap_cmd by adding a USR1 trap with trap_add and confirm exists with get_trap_cmd " {
    
    trap_add "echo 'hello bats test'" USR1
    [ "$?" -eq 0 ]
    # res=$(get_trap_cmd USR1 | tr -d '\n')
    run _tst_get_trap USR1
    [ "$?" -eq 0 ]
    # echo -E "# get_trap_cmd USR1 - res: $res" >&3
    [ "${lines[0]}" = "echo 'hello bats test'" ] || fail_print "get_trap_cmd USR1 - lines[0]: ${lines[0]}"
}

@test "test trap_add+get_trap_cmd by adding two USR1 traps and confirm both commands in trap " {
    trap_add "echo 'hello bats one'" USR1
    trap_add "echo 'hello bats two'" USR1
    [ "$?" -eq 0 ]
    # res=$(get_trap_cmd USR1 | tr -d '\n')
    run _tst_get_trap USR1
    [ "$status" -eq 0 ]
    # echo -E "# get_trap_cmd USR1 x2 - output: $output" >&3
    [ "${lines[0]}" = "echo 'hello bats one'" ] || fail_print "get_trap_cmd USR1 x2 - lines[0]: ${lines[0]}"
    [ "${lines[1]}" = "echo 'hello bats two'" ] || fail_print "get_trap_cmd USR1 x2 - lines[1]: ${lines[1]}"
}

@test "test get_trap_cmd does not return anything with non-existent USR2 trap" {
    res=$(get_trap_cmd USR2 | tr -d '\n')
    [ "$?" -eq 0 ]
    [ -z "$res" ] || fail_print "get_trap_cmd USR2 - res: $res"
}