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
let read_file path =
        let c = open_in path in
        let line = input_line c in
        close_in c;
        line

(* write file content *)
let write_file path str =
        let c = open_out path in
        fprintf c "%s\n" str;
        close_out c

(* check if smt/ht is enabled *)
let smt_enabled () =
        match (read_file "/sys/devices/system/cpu/smt/active") with
        | "1" -> true
        | _ -> false

let smt_disable () =
        write_file "/sys/devices/system/cpu/smt/control" "off"

let string_of_cores c =
        let m = Cores.fold (fun x a -> string_of_int x::a) c [] in
        String.concat "," (List.rev m)

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
        printf "IRQ interrupt assignment: \n";
        let irq_path = "/proc/irq" in
        (* some IRQs can't be reassigned *)
        let ignore_irqs = [0;2;130] in
        Array.iter (fun irq ->
                (* /proc/irq/*/smp_affinity_list *)
                let f = Filename.concat (Filename.concat irq_path irq) "smp_affinity_list" in
                if (Sys.file_exists f) then begin
                        let irq_cores = parse_core_list (read_file f) in
                        printf " - IRQ %s, " irq;
                        if not (List.mem (int_of_string irq) ignore_irqs) then begin
                                if not (Cores.disjoint isol_cores irq_cores) then begin 
                                        let remaining_cores = Cores.diff irq_cores isol_cores in
                                        printf "reconfiguring (%s) -> (%s)..." (string_of_cores irq_cores) (string_of_cores remaining_cores);
                                        write_file f (string_of_cores remaining_cores);
                                        printf "\n"
                                end else
                                        printf "ok\n"
                        end else
                                printf "ignored\n"
                end
        ) (Sys.readdir irq_path);
                
        (* check intel turbo boost  *)
        printf "Disabling turbo boost: ";
        let no_turbo_f = "/sys/devices/system/cpu/intel_pstate/no_turbo" in
        if (Sys.file_exists no_turbo_f) then begin
                write_file no_turbo_f "1";
                printf "intel_pstabe/no_turbo=1 "
        end;
        let boost_f = "/sys/devices/system/cpu/cpufreq/boost" in
        if (Sys.file_exists boost_f) then begin
                write_file boost_f "0";
                printf "cpufreq/boost=0 "
        end;
        printf "\n";

        (* check cpu governor *)
        printf "Set CPU scaling governor on isolated cores: \n";
        Cores.iter (fun cpu ->
                let f = sprintf "/sys/devices/system/cpu/cpu%d/cpufreq/scaling_governor" cpu in
                if (Sys.file_exists f) then begin
                        let orig = read_file f in
                        write_file f "performance";
                        printf " - CPU core %d -> %s (was %s)\n" cpu (read_file f) orig
                end
        ) isol_cores;
