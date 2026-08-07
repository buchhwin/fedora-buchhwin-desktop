# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
#
# Two phases live in this one file, and they run at opposite ends of the
# install. That is unusual enough to explain rather than leave to be discovered:
#
#   phase_gpu     runs SECOND, right after preflight. The akmod build is the
#                 slowest and most failure-prone step in the whole installer,
#                 and finding out after forty minutes that the running kernel
#                 has no headers is worse than finding out after one. It needs
#                 nothing from phase_base because the detector reads sysfs.
#   phase_codecs  runs AFTER apps, because `dnf swap mesa-va-drivers ...`
#                 requires mesa to already be installed, and mesa arrives with
#                 niri in phase_desktop.
#
# They share rpmfusion_enable(), which is why they are not two files.
#
# ⚠️⚠️ NOTHING IN HERE MAY CALL `die`. An abort leaves the machine with no
# desktop at all in order to protect a GPU the desktop does not use: niri draws
# on the integrated graphics, whose driver is in the kernel. Every failure below
# warns with the exact next command, counts itself (phase_summary prints the
# total) and carries on. That is the same contract lib/30-desktop.sh already
# uses for the two COPRs.

# ---------------------------------------------------------------------------
# RPM Fusion, free and nonfree. Idempotent.
#
# ⚠️ THE RELEASE RPMs, NOT `dnf config-manager`. config-manager comes from
# dnf-plugins-core, which is installed in phase_base — and phase_base runs
# AFTER this. The release packages need nothing but dnf and a network, and this
# is also the form RPM Fusion's own instructions use.
rpmfusion_enable() {
    rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1 && return 0
    local v; v="$(rpm -E %fedora 2>/dev/null)"
    [[ -n "$v" ]] || { warn "could not read the Fedora release number"; return 1; }
    step "enabling RPM Fusion (free and nonfree)"
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$v.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$v.noarch.rpm" \
        >/dev/null 2>&1 || return 1
    ok "RPM Fusion enabled"
}

# ---------------------------------------------------------------------------
# Every display controller on the machine, one per line: "<pci-address> <vendor>".
#
# ⚠️ SYSFS RATHER THAN `lspci`, and for three reasons that are all practical:
#   1. pciutils is in none of the five package lists. Installing a package in
#      order to decide whether to install a package is a loop.
#   2. This parses a number. lspci prints English, and it has changed wording
#      between versions.
#   3. It hands back the PCI address, which is what /dev/dri/by-path/ names its
#      render nodes after — so the same function answers "is there an NVIDIA"
#      and "what would gpu.renderDevice have to say".
#
# Class 0x03xxxx is a display controller. The vendor IDs are 0x10de NVIDIA,
# 0x1002 AMD, 0x8086 Intel.
#
# ⚠️ THE CLASS TEST IS NOT DECORATION. An NVIDIA laptop GPU brings an HDMI audio
# function on the same card with the same vendor ID and class 0x0403 — matching
# on the vendor alone counts it twice, and "two NVIDIA GPUs" is the kind of
# wrong that then gets acted on. tests/gpu-detect.sh has that exact fixture.
#
# BUCHHWIN_SYSFS is a test seam, in the shape of the existing BUCHHWIN_SHELL_FAKE.
gpu_devices() {
    local root="${BUCHHWIN_SYSFS:-/sys}" d cls vendor
    for d in "$root"/bus/pci/devices/*; do
        [[ -r "$d/class" && -r "$d/vendor" ]] || continue
        cls="$(<"$d/class")"
        [[ "$cls" == 0x03* ]] || continue
        vendor="$(<"$d/vendor")"
        printf '%s %s\n' "$(basename "$d")" "$vendor"
    done
}

# ---------------------------------------------------------------------------
phase_gpu() {
    section "Graphics"

    local devices nvidia_addr="" others=0
    devices="$(gpu_devices)"
    while read -r addr vendor; do
        [[ -n "$addr" ]] || continue
        if [[ "$vendor" == 0x10de ]]; then nvidia_addr="$addr"; else others=$(( others + 1 )); fi
    done <<< "$devices"

    if [[ -z "$nvidia_addr" ]]; then
        ok "no NVIDIA GPU — nothing to install"
        return 0
    fi

    if (( others )); then
        step "hybrid graphics: niri draws on the integrated GPU; the NVIDIA at $nvidia_addr is for offloading and the external outputs"
    else
        step "NVIDIA at $nvidia_addr, and it is the only GPU"
    fi

    # ------------------------------------------------------------- the repo
    rpmfusion_enable || {
        warn "RPM Fusion could not be enabled — no NVIDIA driver, no codecs"
        warn "  when the network is back: ./install.sh --only gpu"
        return 0
    }

    # -------------------------------------------------- the kernel's headers
    #
    # ⚠️ CHECKED BEFORE akmod-nvidia, NOT AFTER. Without matching kernel-devel
    # the module cannot build, and the failure surfaces as a driver that is
    # installed and does not exist — the single most confusing state this can
    # end in. Returning here means no karg and no MOK either.
    local kver; kver="$(uname -r)"
    if ! rpm -q "kernel-devel-$kver" >/dev/null 2>&1; then
        step "kernel-devel for $kver"
        sudo dnf install -y "kernel-devel-$kver" >/dev/null 2>&1
    fi
    if ! rpm -q "kernel-devel-$kver" >/dev/null 2>&1; then
        warn "the running kernel $kver has no kernel-devel in the repositories"
        warn "  run: sudo dnf upgrade --refresh && reboot, then ./install.sh --only gpu"
        return 0
    fi

    # ------------------------------------------------------------ the driver
    mapfile -t pkgs < <(read_list dnf-gpu.txt)
    step "${#pkgs[@]} packages"
    dnf_install noweak "${pkgs[@]}" || {
        warn "the NVIDIA packages did not install — the desktop is unaffected"
        return 0
    }

    # ⚠️ THE BUILD IS ASYNCHRONOUS. akmods hooks the RPM transaction and can
    # still be compiling when dnf returns, so asking straight away answers "no"
    # on a machine where everything is fine. One forced, synchronous build is
    # cheaper than a wrong answer, and it is a no-op when the module is there.
    if ! modinfo -F version nvidia >/dev/null 2>&1; then
        step "building the module for $kver (this takes a few minutes)"
        sudo akmods --force --kernels "$kver" >/dev/null 2>&1
    fi
    if ! modinfo -F version nvidia >/dev/null 2>&1; then
        warn "the nvidia module did not build — see /var/cache/akmods/nvidia/"
        warn "  the desktop is unaffected: niri draws on the integrated GPU"
        # ⚠️ AND NO MOK IMPORT. A signing key enrolled for a module that does
        # not exist is a password typed for nothing, plus a reboot interruption
        # that buys nothing.
        return 0
    fi
    ok "nvidia $(modinfo -F version nvidia 2>/dev/null) built for $kver"

    # ---------------------------------------------------------- kernel flags
    #
    # `nvidia-drm.modeset=1` is what makes the driver usable under a Wayland
    # compositor at all. `NVreg_DynamicPowerManagement=0x02` lets the dGPU
    # power down when nothing is using it — his choice on 07.08.2026, and the
    # one setting in here that a laptop feels every day.
    #
    # ⚠️ LOOKED UP BEFORE IT IS SET, in both places it can already be true.
    # Recent drivers default modeset to 1 and RPM Fusion ships a modprobe
    # drop-in, so adding it blindly writes a claim into the boot line that
    # nobody can audit afterwards.
    if command -v grubby >/dev/null; then
        local want=() have
        have="$(sudo grubby --info=ALL 2>/dev/null)"
        if ! grep -q 'nvidia-drm.modeset=1' <<< "$have" \
           && ! grep -rqs 'modeset=1' /usr/lib/modprobe.d/*nvidia* /etc/modprobe.d/*nvidia* 2>/dev/null; then
            want+=(nvidia-drm.modeset=1)
        fi
        grep -q 'NVreg_DynamicPowerManagement' <<< "$have" \
            || want+=(nvidia.NVreg_DynamicPowerManagement=0x02)
        if (( ${#want[@]} )); then
            sudo grubby --update-kernel=ALL --args="${want[*]}" >/dev/null 2>&1 \
                && ok "kernel flags: ${want[*]}" \
                || warn "could not set the kernel flags: ${want[*]}"
        else
            ok "kernel flags already in place"
        fi
    else
        warn "grubby is missing — set this by hand:"
        warn "  sudo grubby --update-kernel=ALL --args='nvidia-drm.modeset=1 nvidia.NVreg_DynamicPowerManagement=0x02'"
    fi

    gpu_secureboot
}

# ---------------------------------------------------------------------------
# Secure Boot: sign the module and enrol the key.
#
# ⚠️ THE INSTALLER DOES THE WORK — his decision, and the alternative fails on
# its own terms. "Detect and print four commands" asks the user to be the
# installer, and one of those commands prompts for a password whose only purpose
# is a screen they will meet ten minutes later at boot.
#
# ⚠️ WHAT THIS COSTS, stated because it is a real cost: `mokutil --import`
# schedules a MANDATORY interaction at the next boot — a blue MOK Manager screen
# with a short timeout. Miss it and the key is not enrolled.
#
# ⚠️ AND WHY THAT IS ACCEPTABLE HERE, which is the whole argument: the desktop
# does not depend on it. niri draws on the integrated GPU. A missed enrolment
# costs the dGPU and nothing else, it is repeatable at any time, and both
# `bhctl doctor` and the settings window keep saying so until it is done.
gpu_secureboot() {
    command -v mokutil >/dev/null || {
        warn "mokutil is missing — cannot tell whether Secure Boot will block the driver"
        return 0
    }

    local sb; sb="$(mokutil --sb-state 2>&1)"
    case "$sb" in
        *"SecureBoot disabled"*|*"not supported"*|*"disabled"*)
            ok "Secure Boot is off — the module needs no signature"
            return 0 ;;
        *"SecureBoot enabled"*|*"enabled"*) ;;
        *)  warn "could not read the Secure Boot state (mokutil said: $sb)"
            return 0 ;;
    esac

    # akmods signs with this key. It generates one on first use, but only when
    # something asks it to, so ask.
    local key=/etc/pki/akmods/certs/public_key.der   # english-ok: .der is the certificate encoding
    if [[ ! -f "$key" ]]; then
        sudo /usr/sbin/kmodgenca -a >/dev/null 2>&1 \
            || { warn "could not generate the akmods signing key"; return 0; }
    fi

    # ⚠️ THIS IS WHAT MAKES RE-RUNNING SAFE. Without it every run schedules
    # another enrolment, and the user meets the blue screen again on every
    # reboot after every install.
    if mokutil --test-key "$key" 2>/dev/null | grep -q "already enrolled"; then
        ok "the akmods key is already enrolled — the module will load"
        return 0
    fi

    # ⚠️ NO TTY, NO PROMPT. `mokutil --import` asks for a password on stdin; an
    # install piped from curl would hang for ever on an invisible prompt.
    if [[ ! -t 0 ]]; then
        warn "Secure Boot is on and the akmods key is not enrolled."
        warn "  this step needs a terminal — run: ./install.sh --only gpu"
        return 0
    fi

    printf '\n'
    printf '  Secure Boot is on, and the NVIDIA module is not signed for it yet.\n'
    printf '\n'
    printf '  You will be asked for a ONE-TIME password twice, now.\n'
    printf '  At the NEXT REBOOT a blue screen appears and asks for it once.\n'
    printf '  Choose "Enroll MOK" -> Continue -> Yes, and type that password.\n'
    printf '  The screen has a short timeout and does not come back on its own.\n'
    printf '\n'
    printf '  If you miss it, nothing breaks: the desktop draws on the integrated\n'
    printf '  GPU and comes up either way. Only the NVIDIA card stays unused, and\n'
    printf '  "bhctl doctor" will keep telling you how to finish it.\n'
    printf '\n'
    # ⚠️ NEVER `--root-pw`. It changes what the blue screen asks for, and
    # getting that wrong needs a second computer to fix.
    if sudo mokutil --import "$key"; then
        ok "key enrolment scheduled — REBOOT and answer the blue screen"
    else
        warn "mokutil --import did not complete — run it again with:"
        warn "  sudo mokutil --import $key"
    fi
}

# ---------------------------------------------------------------------------
# Codecs. Separate from the GPU because it applies to every machine, and after
# `apps` because one of the swaps needs mesa to already be there.
#
# ⚠️ RUNS UNDER --minimal TOO. --minimal means "no applications"; a decoder is a
# capability of the system, not an application, and skipping it produces a
# machine where installing vlc by hand later silently half-works.
phase_codecs() {
    section "Codecs"
    rpmfusion_enable || { warn "RPM Fusion is not available — codecs skipped"; return 0; }

    mapfile -t pkgs < <(read_list dnf-codecs.txt)
    dnf_install weak "${pkgs[@]}" || warn "some codec packages failed"

    # ⚠️ `dnf swap`, not install: these REPLACE Fedora's stripped builds, and
    # installing alongside leaves the stripped one in place.
    if rpm -q ffmpeg-free >/dev/null 2>&1; then
        step "ffmpeg-free -> ffmpeg"
        sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing >/dev/null 2>&1 \
            || warn "could not swap ffmpeg-free for ffmpeg"
    fi
    if rpm -q mesa-va-drivers >/dev/null 2>&1 && ! rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
        step "mesa-va-drivers -> mesa-va-drivers-freeworld"
        sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld >/dev/null 2>&1 \
            || warn "could not swap the mesa VA-API drivers"
    fi
    ok "codecs"
}
