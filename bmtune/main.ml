open Printf

module Cores = Set.Make(struct type t = int let compare = compare end)

(* Parse lists of numbers separated by ,. Ranges in the format "x-y" will be
 * expanded. For example "1,3,6-8" will become [1;3;6;7;8]. This format is used
 * to specify core numbers in /proc and /sys. Returns set of int *)
let parse_core_list s =
        (* generate list of ints from a to b when a <= b, inclusive *)
        let rec gen_seq a b =
                match a==b with
                | true -> [b]
                | false -> a :: (gen_seq (a+1) b)
        in
        (* process one number or range "x-y" from a list *)
        let process_elt elt =
                match (String.split_on_char '-' elt) with
                | [a] -> [int_of_string a]
                | a::b::[] -> gen_seq (int_of_string a) (int_of_string b)
                | _ -> raise (Failure "parsing error, invalid range")
        in
        let split = String.split_on_char ',' s in
        Cores.of_list (List.concat (List.map process_elt split))

(* read full content of file and return as string *)
let read_file f =
        let c = open_in f in
        let line = input_line c in
        close_in c;
        line

(* check if smt/ht is enabled *)
let smt_enabled () =
        match (read_file "/sys/devices/system/cpu/smt/active") with
        | "1" -> true
        | _ -> false

let smt_disable () =
        let f = open_out "/sys/devices/system/cpu/smt/control" in
        fprintf f "%s\n" "off";
        close_out f

let () =
        printf "-- checking and preparing system for benchmarking ---\n";

        (* isolcpus *)
        let isol_cores = parse_core_list (read_file "/sys/devices/system/cpu/isolated") in
        if (Cores.is_empty isol_cores) then begin
                printf "no isolated cores cound (check the isolcpus kernel parameter)";
                exit (-1)
        end;
        printf "Isolated cores: ";
        Cores.iter (printf "%d ") isol_cores;
        printf "\n";

        (* nohz_full *)
        let nohz_full_cores = parse_core_list (read_file "/sys/devices/system/cpu/nohz_full") in
        printf "nohz_full: ";

        if (not (Cores.subset isol_cores nohz_full_cores)) then begin
                printf "failed\n";
                printf "WARNING: not all isolated cores have nohz_full enabled. Timer interrupts on the isolated cores could affect the results.\n"
        end else begin
                printf "passed\n";
        end;

        (* check smt/ht *)
        printf "SMT/Hyperthreading: ";
        if (smt_enabled ()) then begin
                printf "SMT/Hyperthreading is enabled, attempting to disable...";
                smt_disable ();
                if (smt_enabled ()) then begin
                        printf "failed.\nWARNING: Unable to disable SMT/Hyperthreading. SMT cores have shared cache which will likely affect results.\n";
                end else
                        printf "done.\n"
        end else
        begin
                printf "passed\n";
        end;

        (* check irqs *)
        printf "IRQ interrupts: \n";
        

        (* check governor *)

        (* check intel *)
        (* disable boost *)


