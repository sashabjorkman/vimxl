local constants = {}

-- Used to skip indentation on line-wrap.
constants.LEADING_INDENTATION_REGEX = "^[\t ]*"

-- Used mainly by word-navigation.
constants.WHITESPACE = " \t\n\r"

-- Vertical tabulation and form feed excluded because does anyone ever use those?
constants.PRINTABLE_CHARACTERS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r"

-- This is the value that will be used for keymap lookups if an operator name
-- is repeated. Used to map commands like (yy) and (dd).
constants.MOTION_LINE_REPEAT = 11

-- We don't want to directly bind 0 as someone might want to write
-- 10 as a numerical argument. Leading zero will only match if no other
-- digit has been entered yet. Used to bind goto first column.
constants.LEADING_ZERO = 12

-- For passing the ctrl+v as a "key" to VimState.
constants.CTRL_V = 13

-- Constants used in more than one file.
return constants
