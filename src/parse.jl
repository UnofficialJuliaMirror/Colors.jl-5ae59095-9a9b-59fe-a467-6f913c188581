# Helper data for color parsing
include("names_data.jl")


# Color Parsing
# -------------

const col_pat_hex1 = r"(#|0x)([[:xdigit:]])([[:xdigit:]])([[:xdigit:]])"
const col_pat_hex2 = r"(#|0x)([[:xdigit:]]{2})([[:xdigit:]]{2})([[:xdigit:]]{2})"
const col_pat_rgb  = r"rgb\((\d+%?),(\d+%?),(\d+%?)\)"
const col_pat_hsl  = r"hsl\((\d+%?),(\d+%?),(\d+%?)\)"
const col_pat_rgba = r"rgba\((\d+%?),(\d+%?),(\d+%?),(\d+(?:\.\d*)?%?)\)"
const col_pat_hsla = r"hsla\((\d+%?),(\d+%?),(\d+%?),(\d+(?:\.\d*)?%?)\)"

# Parse a number used in the "rgb()" or "hsl()" color.
function parse_rgb(num::AbstractString)
    if num[end] == '%'
        return clamp(parse(Int, num[1:end-1], base=10) / 100, 0, 1)
    else
        return clamp(parse(Int, num, base=10) / 255, 0, 1)
    end
end

function parse_hsl_hue(num::AbstractString)
    if num[end] == '%'
        error("hue cannot end in %")
    else
        return parse(Int, num, base=10)
    end
end

function parse_hsl_sl(num::AbstractString)
    if num[end] != '%'
        error("saturation and lightness must end in %")
    else
        return parse(Int, num[1:end-1], base=10) / 100
    end
end

# Parse a number used in the alpha field of "rgba()" and "hsla()".
function parse_alpha_num(num::AbstractString)
    if num[end] == '%'
        return parse(Int, num[1:end-1]) / 100
    else
        return parse(Float32, num)
    end
end

function _parse_colorant(desc::AbstractString)
    desc_ = replace(desc, " " => "")
    mat = match(col_pat_hex2, desc_)
    if mat != nothing
        return RGB{N0f8}(parse(Int, mat.captures[2], base=16) / 255,
                       parse(Int, mat.captures[3], base=16) / 255,
                       parse(Int, mat.captures[4], base=16) / 255)
    end

    mat = match(col_pat_hex1, desc_)
    if mat != nothing
        return RGB{N0f8}(parse(Int, mat.captures[2], base=16) / 15,
                       parse(Int, mat.captures[3], base=16) / 15,
                       parse(Int, mat.captures[4], base=16) / 15)
    end

    mat = match(col_pat_rgb, desc_)
    if mat != nothing
        return RGB{N0f8}(parse_rgb(mat.captures[1]),
                       parse_rgb(mat.captures[2]),
                       parse_rgb(mat.captures[3]))
    end

    mat = match(col_pat_hsl, desc_)
    if mat != nothing
        return HSL{ColorTypes.eltype_default(HSL)}(parse_hsl_hue(mat.captures[1]),
                                        parse_hsl_sl(mat.captures[2]),
                                        parse_hsl_sl(mat.captures[3]))
    end

    mat = match(col_pat_rgba, desc_)
    if mat != nothing
        return RGBA{N0f8}(parse_rgb(mat.captures[1]),
                        parse_rgb(mat.captures[2]),
                        parse_rgb(mat.captures[3]),
                        parse_alpha_num(mat.captures[4]))
    end

    mat = match(col_pat_hsla, desc_)
    if mat != nothing
        return HSLA{ColorTypes.eltype_default(HSLA)}(parse_hsl_hue(mat.captures[1]),
                                          parse_hsl_sl(mat.captures[2]),
                                          parse_hsl_sl(mat.captures[3]),
                                          parse_alpha_num(mat.captures[4]))
    end


    desc_ = lowercase(desc_)

    if desc_ == "transparent"
        return RGBA{N0f8}(0,0,0,0)
    end

    if !haskey(color_names, desc_)
        error("Unknown color: ", desc)
    end

    c = color_names[desc_]
    return RGB{N0f8}(c[1] / 255, c[2] / 255, c[3] / 255)
end

# note: these exist to enable proper dispatch, since super(Colorant) == Any
_parse_colorant(::Type{C}, ::Type{SUP}, desc::AbstractString) where {C<:Colorant,SUP<:Any} = _parse_colorant(desc)
_parse_colorant(::Type{C}, ::Type{SUP}, desc::AbstractString) where {C<:Colorant,SUP<:Colorant} = convert(C, _parse_colorant(desc))::C

"""
    parse(Colorant, desc)

Parse a color description.

This parses a subset of HTML/CSS color specifications. In particular, everything
is supported but: `currentColor`.

It does support named colors (though it uses X11 named colors, which are
slightly different than W3C named colors in some cases), `rgb()`, `hsl()`,
`#RGB`, and `#RRGGBB` syntax.

# Arguments

- `Colorant`: literal Colorant
- `desc`: color name or description

A literal Colorant will parse according to the `desc` string (usually returning an `RGB`); any more specific choice will return a color of the specified type.

# Returns

- an `RGB{N0f8}` color, or

- an `HSL` color if `hsl(h, s, l)` was used

- an `RGBA` color if `rgba(r, g, b, a)` was used

- an `HSLA` color if `hsla(h, s, l, a)` was used

- a specific `Colorant` type as specified in the first argument
"""
Base.parse(::Type{C}, desc::AbstractString) where {C<:Colorant} = _parse_colorant(C, supertype(C), desc)
Base.parse(::Type{C}, desc::Symbol) where {C<:Colorant} = parse(C, string(desc))
Base.parse(::Type{C}, c::Colorant) where {C<:Colorant} = c

"""
    @colorant_str(ex)

Parse a literal color name as a Colorant.
"""
macro colorant_str(ex)
    isa(ex, AbstractString) || error("colorant requires literal strings")
    col = parse(Colorant, ex)
    :($col)
end

@noinline function ColorTypes.color(str::AbstractString)
    Base.depwarn("color(\"$str\") is deprecated, use colorant\"$str\" or parse(Colorant, \"$str\")", :color)
    parse(Colorant, str)
end
