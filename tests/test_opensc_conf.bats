#!/usr/bin/env bats
# tests/test_opensc_conf.bats — Unit tests for lib/opensc_conf.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    # Override OPENSC_CONF to a temp file — avoids needing /etc/opensc/opensc.conf
    export OPENSC_CONF="$BATS_TMPDIR/opensc.conf"
    _source_lib "opensc_conf"
}

teardown() {
    rm -f "$_CAC_LOG_FILE" "$BATS_TMPDIR/opensc.conf"
}

@test "configure_opensc_cac_driver adds force_card_driver to opensc.conf" {
    printf 'app default {\n}\n' > "$OPENSC_CONF"
    configure_opensc_cac_driver
    grep -q "force_card_driver" "$OPENSC_CONF"
}

@test "configure_opensc_cac_driver is idempotent (no duplicate entries)" {
    printf 'app default {\n}\n' > "$OPENSC_CONF"
    configure_opensc_cac_driver
    configure_opensc_cac_driver
    local count
    count="$(grep -c "force_card_driver" "$OPENSC_CONF")"
    [ "$count" -eq 1 ]
}

@test "configure_opensc_cac_driver appends app default block when absent" {
    printf '# opensc config\n' > "$OPENSC_CONF"
    configure_opensc_cac_driver
    grep -q "app default" "$OPENSC_CONF"
    grep -q "force_card_driver" "$OPENSC_CONF"
}

@test "configure_opensc_cac_driver warns and returns 0 when file missing" {
    rm -f "$OPENSC_CONF"
    run configure_opensc_cac_driver
    [ "$status" -eq 0 ]
}

@test "configure_opensc_cac_driver adds force_card_driver when default config has commented-out directive" {
    # The real Arch/CachyOS opensc.conf ships with force_card_driver commented out.
    # The idempotency check must NOT match the comment — it must add the active line.
    printf 'app default {\n    # force_card_driver = cac;\n}\n' > "$OPENSC_CONF"
    configure_opensc_cac_driver
    # An uncommented force_card_driver = cac line must now be present
    grep -qE "^[[:space:]]*force_card_driver[[:space:]]*=[[:space:]]*" "$OPENSC_CONF"
}
