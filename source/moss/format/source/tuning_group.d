/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.tuning_group
 *
 * Allows for specifying groups of tuning options and collectively
 * enabling/disabling them.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.tuning_group;

public import moss.format.source.schema;

/**
 * Each TuningOption can set one or more TuningFlag combinations to
 * be enabled when in the ENABLED or DISABLED state.
 *
 * Most flags will not turn anything *on* when disabled, but to ensure
 * consistency between compiler versions we'll explicitly set their
 * counter value, i.e. -fcommon vs -fno-common.
 *
 * Thus, enabling a tuning option or disabling it involves collecting
 * the full set of tuning flag *names* from either the enabled or disabled
 * states, condensing them, and building the full flag set from there.
 */
struct TuningOption
{
    /** Set of TuningFlags to be enabled when this option is enabled */
    @YamlSchema("enabled", false, YamlType.Array) string[] onEnabled;

    /** Set of TuningFlags to be enabled when this option is disabled */
    @YamlSchema("disabled", false, YamlType.Array) string[] onDisabled;
}

/**
 * A TuningGroup may contain default boolean "on" "off" values, or
 * it may contain them via choices, i.e. "=speed"
 */
struct TuningGroup
{
    /** Root namespace group option */
    TuningOption root;

    /** Mapping of string (key) to TuningOption multiple choices */
    TuningOption[string] choices;

    /** Default TuningOption to enable with multiple choice group */
    @YamlSchema("default") string defaultChoice = null;
}
