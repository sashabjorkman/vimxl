local constants = {}

constants.LEADING_INDENTATION_REGEX = "^[\t ]*"
constants.WHITESPACE = " \t\n\r"

-- Vertical tabulation and form feed excluded because does anyone ever use those?
constants.PRINTABLE_CHARACTERS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r"

constants.MOTION_LINE_REPEAT = 11
constants.LEADING_ZERO = 12

return constants
