#############################################################################
# Copyright (C) 2017 - 2023  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

"""
    initialize_concept_dictionary(template::Dict; translation::Dict=Dict())

Gathers information from `spineopt_template.json` and forms a `Dict` for the concepts according to `translation`.

Unfortunately, the template is not uniform when it comes to the location of the `name` of each concept, their related
concepts, or the `description`.
Thus, we have to map things somewhat manually here.
The optional `translation` keyword can be used to aggregate and translate the output using the
`translate_and_aggregate_concept_dictionary()` function.
"""
function initialize_concept_dictionary(template::Dict; translation::Dict=Dict())
    # Define mapping of template entries, where each attribute of interest is.

    template_keys = [
        "object_classes",
        "relationship_classes",
        "parameter_value_lists",
        "object_parameters",
        "relationship_parameters",
        "tools",
        "features",
        "tool_features"
        ]

    template_mapping = Dict(
        "object_classes" => Dict(:name_index => 1, :description_index => 2),
        "relationship_classes" => Dict(
            :name_index => 1,
            :description_index => 3,
            :related_concept_index => 2,
            :related_concept_type => "object_classes",
        ),
        "parameter_value_lists" => Dict(:name_index => 1, :possible_values_index => 2),
        "object_parameters" => Dict(
            :name_index => 2,
            :description_index => 5,
            :related_concept_index => 1,
            :related_concept_type => "object_classes",
            :default_value_index => 3,
            :parameter_value_list_index => 4,
        ),
        "relationship_parameters" => Dict(
            :name_index => 2,
            :description_index => 5,
            :related_concept_index => 1,
            :related_concept_type => "relationship_classes",
            :default_value_index => 3,
            :parameter_value_list_index => 4,
        ),
        "tools" => Dict(:name_index => 1, :description_index => 2),
        "features" => Dict(
            :name_index => 2,
            :related_concept_index => 1,
            :related_concept_type => "object_classes",
            :default_value_index => 3,
            :parameter_value_list_index => 4,
        ),
        "tool_features" => Dict(
            :name_index => 1,
            :related_concept_index => 2,
            :related_concept_type => "object_classes",
            :default_value_index => 4,
            :feature_index => 4,
        ),
    )
    # Initialize the concept dictionary based on the template (only preserves the last entry, if overlaps)
    concept_dictionary = Dict(
        key => Dict(
            entry[template_mapping[key][:name_index]] => Dict(
                :description => isnothing(get(template_mapping[key], :description_index, nothing)) ? nothing :
                                entry[template_mapping[key][:description_index]],
                :default_value => isnothing(get(template_mapping[key], :default_value_index, nothing)) ? nothing :
                                  entry[template_mapping[key][:default_value_index]],
                :parameter_value_list => isnothing(get(template_mapping[key], :parameter_value_list_index, nothing)) ?
                                         nothing : entry[template_mapping[key][:parameter_value_list_index]],
                :possible_values => isnothing(get(template_mapping[key], :possible_values_index, nothing)) ? nothing :
                                    [entry[template_mapping[key][:possible_values_index]]],
                :feature => isnothing(get(template_mapping[key], :feature_index, nothing)) ? nothing :
                            entry[template_mapping[key][:feature_index]],
                :related_concepts => isnothing(get(template_mapping[key], :related_concept_index, nothing)) ? Dict() :
                                     Dict(
                    template_mapping[key][:related_concept_type] => (isa(
                        entry[template_mapping[key][:related_concept_index]],
                        Array,
                    ) ? (unique([
                        entry[template_mapping[key][:related_concept_index]]...,
                    ])) : [
                        entry[template_mapping[key][:related_concept_index]],
                    ]),
                ),
            ) for entry in template[key] 
        ) for key in template_keys
    )
    # Perform a second pass to cover overlapping entries and throw warnings for conflicts
    for key in template_keys
        for entry in template[key]
            concept = concept_dictionary[key][entry[template_mapping[key][:name_index]]]
            # Check for conflicts in `description`, `default_value`, `parameter_value_list`, `feature`
            if !isnothing(concept[:description]) &&
               concept[:description] != entry[template_mapping[key][:description_index]]
                @warn "`$(entry[template_mapping[key][:name_index]])` has conflicting `description` across duplicate template entries!"
            end
            if !isnothing(concept[:default_value]) &&
               concept[:default_value] != entry[template_mapping[key][:default_value_index]]
                @warn "`$(entry[template_mapping[key][:name_index]])` has conflicting `default_value` across duplicate template entries!"
            end
            if !isnothing(concept[:parameter_value_list]) &&
               concept[:parameter_value_list] != entry[template_mapping[key][:parameter_value_list_index]]
                @warn "`$(entry[template_mapping[key][:name_index]])` has conflicting `parameter_value_list` across duplicate template entries!"
            end
            if !isnothing(concept[:possible_values]) && !isnothing(entry[template_mapping[key][:possible_values_index]])
                unique!(push!(concept[:possible_values], entry[template_mapping[key][:possible_values_index]]))
            end                
            if !isnothing(concept[:feature]) && concept[:feature] != entry[template_mapping[key][:feature_index]]
                @warn "`$(entry[template_mapping[key][:name_index]])` has conflicting `parameter_value_list` across duplicate template entries!"
            end
            # Include all unique `concepts` into `related concepts`
            if !isempty(concept[:related_concepts])
                if isa(entry[template_mapping[key][:related_concept_index]], Array)
                    related_concepts = unique([entry[template_mapping[key][:related_concept_index]]...])
                else
                    related_concepts = [entry[template_mapping[key][:related_concept_index]]]
                end
                unique!(
                    append!(concept[:related_concepts][template_mapping[key][:related_concept_type]], related_concepts),
                )
            end
        end
    end
    # If translation and aggregation is defined, do that.
    if !isempty(translation)
        concept_dictionary = translate_and_aggregate_concept_dictionary(concept_dictionary, translation)
    end
    return concept_dictionary
end

"""
    _unique_merge!(value1, value2)

Merges two values together provided it's possible depending on the type.
"""
unique_merge!(value1::Dict, value2::Dict) = merge!(value1, value2)
unique_merge!(value1::String, value2::String) = value1
unique_merge!(value1::Bool, value2::Bool) = value1
unique_merge!(value1::Array, value2::Array) = unique!(append!(value1, value2))
unique_merge!(value1::Nothing, value2::Nothing) = nothing

"""
    translate_and_aggregate_concept_dictionary(concept_dictionary::Dict, translation::Dict)

Translates and aggregates the concept types of the initialized `concept_dictionary` according to `translation`.

`translation` needs to be a `Dict` with arrays of `String`s corresponding to the template sections mapped to
a `String` corresponding to the translated section name.
If multiple template section names are mapped to a single `String`, the entries are aggregated under that title.
"""
function translate_and_aggregate_concept_dictionary(concept_dictionary::Dict, translation::Dict)
    initial_translation = Dict(
        translation[key] => merge(
            (d1, d2) -> merge(unique_merge!, d1, d2),
            [concept_dictionary[k] for k in key]...
        )
        for key in keys(translation)
    )
    translated_concept_dictionary = deepcopy(initial_translation)
    for concept_type in keys(initial_translation)
        for concept in keys(initial_translation[concept_type])
            translated_concept_dictionary[concept_type][concept][:related_concepts] = Dict(
                translation[key] => vcat(
                    [
                        initial_translation[concept_type][concept][:related_concepts][k]
                        for k in key if k in keys(initial_translation[concept_type][concept][:related_concepts])
                    ]...,
                ) for key in keys(translation)
            )
        end
    end
    return translated_concept_dictionary
end

"""
    add_cross_references!(concept_dictionary::Dict)

Loops over the `concept_dictionary` and cross-references all `:related_concepts`.
"""
function add_cross_references!(concept_dictionary::Dict)
    # Loop over the concept dictionary and cross-reference all related concepts.
    for class in keys(concept_dictionary)
        for concept in keys(concept_dictionary[class])
            for related_concept_class in keys(concept_dictionary[class][concept][:related_concepts])
                for related_concept in concept_dictionary[class][concept][:related_concepts][related_concept_class]
                    if !isnothing(
                        get(
                            concept_dictionary[related_concept_class][related_concept][:related_concepts],
                            class,
                            nothing,
                        ),
                    )
                        if concept in concept_dictionary[related_concept_class][related_concept][:related_concepts][class]
                            nothing
                        else
                            push!(
                                concept_dictionary[related_concept_class][related_concept][:related_concepts][class],
                                concept,
                            )
                        end
                    else
                        concept_dictionary[related_concept_class][related_concept][:related_concepts][class] = [concept]
                    end
                end
            end
        end
    end
    return concept_dictionary
end

"""
    write_concept_reference_files(
        concept_dictionary::Dict,
        makedocs_path::String
    )

Automatically writes markdown files for the `Concept Reference` chapter based on the `concept_dictionary`.

Each file is pieced together from two parts: the preamble automatically generated using the
`concept_dictionary`, and a separate description assumed to be found under `docs/src/concept_reference/<name>.md`.
"""
function write_concept_reference_files(concept_dictionary::Dict, makedocs_path::String)
    error_count = 0
    for filename in keys(concept_dictionary)
        system_string = ["# $(filename)\n\n"]
        # Loop over the unique names and write their information into the filename under a dedicated section.
        for concept in unique!(sort!(collect(keys(concept_dictionary[filename]))))
            section = "## `$(concept)`\n\n"
            # If description is defined, include it into the preamble.
            if !isnothing(concept_dictionary[filename][concept][:description])
                section *= ">$(concept_dictionary[filename][concept][:description])\n\n"
            end
            # If default values are defined, include those into the preamble
            if !isnothing(concept_dictionary[filename][concept][:default_value])
                if concept_dictionary[filename][concept][:default_value] isa String
                    str = replace(concept_dictionary[filename][concept][:default_value], "_" => "\\_")
                else
                    str = concept_dictionary[filename][concept][:default_value]
                end
                section *= ">**Default value:** $(str)\n\n"
            end
            # If parameter value lists are defined, include those into the preamble
            if !isnothing(concept_dictionary[filename][concept][:parameter_value_list])
                refstring = "[$(replace(concept_dictionary[filename][concept][:parameter_value_list], "_" => "\\_"))](@ref)"
                section *= ">**Uses [Parameter Value Lists](@ref):** $(refstring)\n\n"
            end
            # If possible parameter values are defined, include those into the preamble
            if !isnothing(concept_dictionary[filename][concept][:possible_values])
                strings = [
                    "`$(c)`" for c in concept_dictionary[filename][concept][:possible_values]
                ]
                section *= ">**Possible values:** $(join(sort!(strings), ", ", " and ")) \n\n"
            end
            # If related concepts are defined, include those into the preamble
            if !isempty(concept_dictionary[filename][concept][:related_concepts])
                for related_concept_type in keys(concept_dictionary[filename][concept][:related_concepts])
                    if !isempty(concept_dictionary[filename][concept][:related_concepts][related_concept_type])
                        refstrings = [
                            "[$(replace(c, "_" => "\\_"))](@ref)"
                            for c in concept_dictionary[filename][concept][:related_concepts][related_concept_type]
                        ]
                        section *= ">**Related [$(replace(related_concept_type, "_" => "\\_"))](@ref):** $(join(sort!(refstrings), ", ", " and "))\n\n"
                    end
                end
            end
            # If features are defined, include those into the preamble
            #if !isnothing(concept_dictionary[filename][concept][:feature])
            #    section *= "Uses [Features](@ref): $(join(replace(concept_dictionary[filename][concept][:feature], "_" => "\\_"), ", ", " and "))\n\n"
            #end
            # Try to fetch the description from the corresponding .md filename.
            description_path = joinpath(makedocs_path, "src", "concept_reference", "$(concept).md")
            try
                description = open(f -> read(f, String), description_path, "r")
                while description[(end - 1):end] != "\n\n"
                    description *= "\n"
                end
                push!(system_string, section * description)
            catch
                @warn("Description for `$(concept)` not found! Please add a description to `$(description_path)`.")
                error_count += 1
                push!(system_string, section * "TODO\n\n")
            end
        end
        system_string = join(system_string)
        open(joinpath(makedocs_path, "src", "concept_reference", "$(filename).md"), "w") do file
            write(file, system_string)
        end
    end
    return error_count
end

"""
    drag_and_drop(pages, path)

Reads the folder and file structure to automatically create the documentation, effectively creating a drag and drop feature for select chapters. The functionality is activated for empty chapters ("chapter name" => nothing).

The code assumes a specific structure.
+ All chapters and corresponding markdownfiles are in the "docs/src folder".
+ folder names need to be lowercase with underscores because folder names are derived from the page names
+ markdown file names can have uppercases and can have underscores but don't need to because the page names are derived from file names

Developer note: An alternative approach for this code could be to automatically go over all folders and files (removing the need for a specific structure) and instead use a list "exclude" which indicates which folders and files should be skipped. To deal with folders in folders we could use walkdir() instead of readdir()
"""
function drag_and_drop(pages, path)
    # collect folders as chapters and markdownfiles as pages
    chaptex = Dict()
    for dir in readdir(path)
        if isdir(path*"/"*dir)
            chaptex[dir] = [rd for rd in readdir(path*"/"*dir) if !isdir(path*"/"*dir*"/"*rd) && (rd[end-1:end] == "md" || rd[end-1:end] == "MD")]
        end
    end

    # replace all empty chapters with the 'drag and drop' files
    newpages = []
    for page in pages
        chapname = page.first
        chapfile = lowercase(replace(chapname, " " => "_"))
        if chapfile in keys(chaptex) && page.second == nothing
            texlist = Any[]
            for texfile in chaptex[chapfile]
                texname = split(texfile, ".")[1]
                texname = uppercasefirst(replace(texname, "_" => " "))
                push!(texlist, texname => joinpath(chapfile, texfile))
            end
            push!(newpages, chapname => texlist)
        else
            push!(newpages, page)
        end
    end
    return newpages
end

"""
    alldocstrings(m)

Return all docstrings from the provided module m as a dictionary.
"""
function alldocstrings(m)
    #allbindings(m) = [ [y[2].data[:binding] for y in x[2].docs] for x in Base.eval(m,Base.Docs.META) ]
    bindings = []
    for x in Base.eval(m,Base.Docs.META)
        for y in x[2].docs
            push!(bindings,[y[2].data[:binding]])
        end
    end
    alldocs = Dict()
    for binding in bindings
        dockey = split(string(binding[1]),".")[2]
        docvalue = Base.Docs.doc(binding[1])
        alldocs[dockey] = docvalue
    end
    return alldocs
end

"""
    findregions()

Finds specific regions within a docstring and return them as a single string.
"""
function findregions(docstring; regions=["formulation","description"], title="", fieldtitle=false, sep="\n\n", debugmode=false)
    md = ""
    if !isempty(title)
        md *= title * sep
    end
    for region in regions
        try
            sf1 = findfirst("#region $region",string(docstring))[end]+2
            sf2 = findfirst("#endregion $region",string(docstring))[1]-2
            sf = SubString(string(docstring),sf1,sf2)
            if fieldtitle
                md *= region * sep
            end
            md *= sf * sep
            if debugmode
                println(sf)
            end
        catch
            if debugmode
                @warn "Cannot find #(end)region $region"
                #the error could also be because there is no docstring for constraint but that is a very rare case as there is often at least a dynamic docstring
            end
        end
    end
    return md
end

"""
    docs_from_instructionlist(alldocs, instructionlist)

Create a string from all docstrings in a module with the instructions from the instructionlist.

The instructions currently accept 3 types (see example below):
+ regular strings: these are simply printed to the string
+ instruction strings: strings in between region instruction, intended for use in markdown files
+ instruction tuple: tuple with the same instructions, more directly related to the findregions function

The instruction consists of a function name and a list of regions in the docstring of that function.
If the function name is 'alldocstrings' then it will search all docstrings for the given regions.

Each instruction is separated by two end of line characters.

'''julia
alldocs = alldocstrings(SpineOpt)
instrulist = [
    "# Constraints",
    "## Auto constraint",
    "#region instruction",
    "add_constraint_node_state_capacity!",
    "formulation",
    "#endregion instruction",
    ("add_constraint_node_state_capacity!",["formulation","description"])
]
markdownstring = docs_from_instructionlist(alldocs, instrulist)
'''
"""
function docs_from_instructionlist(alldocs, instructionlist)
    md = ""
    
    function interpret_instruction(functionname,functionfields)
        if functionname == "alldocstrings"
            for (dockey, docvalue) in alldocs
                title = ""
                if occursin("add_constraint", dockey)
                    # remove add_constraint_ as well as !
                    title = "### " * replace(uppercasefirst(dockey[16:end-1]), "_" => " ")
                end
                md *= findregions(docvalue; regions=functionfields, title=title)
            end
        else
            md *= findregions(alldocs[functionname]; regions=functionfields)
        end
    end

    instructionarray = [] #needs to be empty
    for instruction in instructionlist
        if isa(instruction, String)
            if occursin("#region instruction", instruction)
                instructionarray = ["findfields"]
            elseif occursin("#endregion instruction", instruction)
                functionname = instructionarray[2]
                functionfields = instructionarray[3:end]
                interpret_instruction(functionname,functionfields)
                instructionarray = []
            elseif !isempty(instructionarray)
                push!(instructionarray, instruction)
            else
                md *= instruction * "\n"
            end
        elseif isa(instruction,Tuple)
            functionname = instruction[1]
            functionfields = instruction[2]
            interpret_instruction(functionname,functionfields)
        end
    end
    return md
end