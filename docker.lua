local w = require('tables').wrap
local matchers = require('matchers')
local parser = clink.arg.new_parser

local function list(command)
    local res = w()
    local f = io.popen(command)
    if f == nil then return res end

    for line in f:lines() do
        local s = line:find(" ", 1, true)
        if s ~= nil then
            local id = line:sub(0, s - 1)
            local name = line:sub(s + 1)
            table.insert(res, id)
            table.insert(res, name)
        end
    end
    f:close()

    return res
end

local function list_images()
    return list("docker images -q --format \"{{.ID}} {{.Repository}}:{{.Tag}}\" 2>nul")
end

local function images(token)
    return list_images()
    :filter(function(image)
        return clink.is_match(token, image)
    end)
end

local function list_containers(all)
    local command = "docker ps -q"
    if all then
        command = command .. " -a"
    end
    command = command .. " --format \"{{.ID}} {{.Names}}\" 2>nul"
    return list(command)
end

local function running_containers(token)
    return list_containers(false)
    :filter(function(container)
        return clink.is_match(token, container)
    end)
end

local function all_containers(token)
    return list_containers(true)
    :filter(function(container)
        return clink.is_match(token, container)
    end)
end

local empty_parser = parser({})

local docker_exec_flags = {
    "-d", "--detach",
    "-e" .. empty_parser,
    "--env" .. empty_parser,
    "--privileged",
    "-w" .. empty_parser,
    "--workdir" ..empty_parser
}

local docker_image_flags = {
    "-a", "--all",
    "--digests",
    "--format" .. empty_parser,
    "--no-trunc",
    "-q", "--quiet"
}

local docker_start_flags = {
    "-a" .. parser({"STDIN","STDOUT","STDERR"}),
    "--attach" .. parser({"STDIN","STDOUT","STDERR"}),
    "-i", "--interactive",
}

local docker_update_flags = {
    "--blkio-weight" .. empty_parser,
    "--cpu-period" .. empty_parser,
    "--cpu-quota" .. empty_parser,
    "--cpu-rt-period" ..empty_parser,
    "--cpu-rt-runtime" .. empty_parser,
    "-c" .. empty_parser,
    "--cpu-shares" .. empty_parser,
    "--cpus" .. empty_parser,
    "--cpuset-cpus" .. empty_parser,
    "-m" .. empty_parser,
    "--memory" .. empty_parser,
    "--memory-reservation" .. empty_parser,
    "--memory-swap" .. empty_parser,
    "--restart" .. parser({"no", "on-failure", "always", "unless-stopped"}),
}

local docker_run_arg_parser = parser({images},
    "--entrypoint" .. empty_parser,
    "--expose" .. empty_parser,
    "--gpus" .. empty_parser,
    "-h" .. empty_parser,
    "--hostname" .. empty_parser,
    "--init",
    "--link" .. parser({running_containers}),
    "--name" .. empty_parser,
    "--network" .. empty_parser,
    "--no-healthcheck",
    "-p" .. empty_parser,
    "--publish" .. empty_parser,
    "-P", "--publish-all",
    "--pull" .. parser({"always", "missing", "never"}),
    "--read-only",
    "--rm",
    "--shm-size" .. empty_parser,
    "-t", "--tty",
    "-u" .. empty_parser,
    "--user" .. empty_parser,
    "-v" .. empty_parser,
    "--volume" .. empty_parser,
    "--volumes-from" .. parser({all_containers})
):addflags(docker_exec_flags, docker_start_flags, docker_update_flags)

local docker_pull_arg_parser = parser({images},
    "-a", "--all-tags",
    "-q", "--quiet"
)

local docker_stop_arg_parser = parser({all_containers},
    "-t" .. empty_parser,
    "--time" .. empty_parser
):loop(1)

local docker_parser = parser(
    {
        "attach"..parser({running_containers},
            "--detach-keys" .. empty_parser,
            "--no-stdin",
            "--sig-proxy"
        ),
        "build"..parser(
            "-f" .. parser({matchers.files}),
            "--file" .. parser({matchers.files}),
            "--no-cache",
            "--pull",
            "-q", "--quiet",
            "-t" .. parser({images}),
            "--tag" .. parser({images}),
            "--target" .. empty_parser
        ),
        "commit"..parser({all_containers}, {images},
            "-a" .. empty_parser,
            "--author" .. empty_parser,
            "-c" .. empty_parser,
            "--change" .. empty_parser,
            "-m" .. empty_parser,
            "--message" .. empty_parser,
            "-p",
            "--pause"
        ),
        "cp"..parser({all_containers, images}, {all_containers, images},
            "-a", "--archive",
            "-L", "--follow-link"
        ),
        "create" .. docker_run_arg_parser,
        "diff"..parser({running_containers}),
        "events",
        "exec"..parser({running_containers}):addflags(docker_exec_flags),
        "export"..parser({all_containers},
            "-o" .. parser({matchers.files}),
            "--output" .. parser({matchers.files})
        ),
        "history"..parser({images}):addflags(docker_image_flags),
        "images"..parser({images},
            "-f" .. empty_parser,
            "--filter" .. empty_parser
        ):addflags(docker_image_flags):loop(1),
        "import"..parser({matchers.files},
            "-m" .. empty_parser,
            "--message" .. empty_parser
        ),
        "info",
        "inspect"..parser({all_containers, images}, "-s", "--size"):loop(1),
        "kill"..parser({running_containers},
            "-s" .. empty_parser,
            "--signal" .. empty_parser
        ):loop(1),
        "load"..parser(
            "-i" .. parser({matchers.files}),
            "--input" .. parser({matchers.files}),
            "-q"
        ),
        "login"..parser({
                "azure"..parser(
                    "--client-id" .. empty_parser,
                    "--client-secret" .. empty_parser,
                    "--cloud-name" .. parser({"AzureCloud", "AzureChinaCloud", "AzureGermanCloud", "AzureUSGovernment"}),
                    "--tenant-id" .. empty_parser
                )
            },
            "-p" .. empty_parser,
            "--password" .. empty_parser,
            "--password-stdin",
            "-u" .. empty_parser,
            "--username" .. empty_parser
        ),
        "logout"..parser({"azure"}),
        "logs"..parser(
            "--details",
            "-f", "--follow",
            "--since" .. empty_parser,
            "-n" .. empty_parser,
            "--tail" .. empty_parser,
            "-t", "--timestamps",
            "--until" .. empty_parser
        ),
        "pause"..parser({running_containers}):loop(1),
        "port"..parser({all_containers}),
        "ps"..parser(
            "-a", "--all",
            "-f" .. empty_parser,
            "--filter" .. empty_parser,
            "-n" .. empty_parser,
            "--last" .. empty_parser,
            "-l", "--latest",
            "--no-trunc",
            "-q", "--quiet",
            "-s", "--size"
        ),
        "pull"..docker_pull_arg_parser,
        "push"..docker_pull_arg_parser,
        "rename"..parser({all_containers}, {all_containers}),
        "restart"..docker_stop_arg_parser,
        "rm"..parser({all_containers},
            "-f", "--force",
            "-l", "--link",
            "-v", "--volumes"
        ):loop(1),
        "rmi"..parser({images},
            "-f", "--force",
            "--no-prune"
        ):loop(1),
        "run"..docker_run_arg_parser,
        "save"..parser({images},
            "-o" .. parser({matchers.files}),
            "--output" .. parser({matchers.files})
        ):loop(1),
        "search",
        "start"..parser({all_containers}):addflags(docker_start_flags):loop(1),
        "stats"..parser({all_containers},
            "-a", "--all",
            "--no-trunc"
        ):loop(1),
        "stop"..docker_stop_arg_parser,
        "tag"..parser({images},{images}),
        "top"..parser({running_containers}),
        "unpause"..parser({running_containers}):loop(1),
        "update"..parser({all_containers}):addflags(docker_update_flags):loop(1),
        "version",
        "wait"..parser({running_containers}):loop(1)
    },
    "--config" .. parser({matchers.files}),
    "-c" .. empty_parser,
    "--context" .. empty_parser,
    "-D", "--debug",
    "-H" .. empty_parser,
    "--host" .. empty_parser,
    "-l" .. parser({"debug", "info", "warn", "error", "fatal"}),
    "--log-level" .. parser({"debug", "info", "warn", "error", "fatal"}),
    "--tls", "--tlsverify",
    "--tlscacert" .. parser({matchers.files}),
    "--tlscert" .. parser({matchers.files}),
    "--tlskey" .. parser({matchers.files}),
    " -v", "--version",
    "--help"
)

clink.arg.register_parser("docker", docker_parser)
