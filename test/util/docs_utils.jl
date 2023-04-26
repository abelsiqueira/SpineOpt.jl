#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
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

@testset "docs_utils" begin
	default_translation = Dict(
	    ["relationship_classes"] => "Relationship Classes",
	    ["parameter_value_lists"] => "Parameter Value Lists",
	    ["object_parameters", "relationship_parameters"] => "Parameters",
	    ["object_classes"] => "Object Classes",
	)
	#@test_logs min_level=Logging.Warn concept_dictionary = SpineOpt.initialize_concept_dictionary(SpineOpt.template(); translation=default_translation)# use this line instead of the line below once the function has been adjusted to account for duplicates in the to/from structure; not needed when the entire building of the documentation is tested
	concept_dictionary = SpineOpt.initialize_concept_dictionary(SpineOpt.template(); translation=default_translation)
	@test Set(keys(concept_dictionary)) == Set(values(default_translation))
	concept_dictionary = SpineOpt.add_cross_references!(concept_dictionary)
	@test Set(keys(concept_dictionary)) == Set(values(default_translation))
	# #= use this path instead of the path below to test whether the function behaves properly
	path = mktempdir()
	cpt_ref_path = joinpath(path, "src", "concept_reference")
	mkpath(cpt_ref_path)
	for (filename, concepts) in concept_dictionary
        # Loop over the unique names and write their information into the filename under a dedicated section.
        for concept in unique!(collect(keys(concepts)))
            description_path = joinpath(cpt_ref_path, "$(concept).md")
            write(description_path, "\n\n")
        end
    end
	# =#
	#path = dirname(dirname(@__DIR__))*"/docs"# use this path instead of the path above to test the actual documentation; not needed if the entire building of the documentation is tested
	@test_logs min_level=Logging.Warn SpineOpt.write_concept_reference_files(concept_dictionary, path)
	#@test_logs min_level=Logging.Warn include(dirname(dirname(@__DIR__))*"/docs/make.jl")# use this line to test the entire building process of the actual documentation
end