var documenterSearchIndex = {"docs":
[{"location":"#SpineModel.jl-1","page":"Home","title":"SpineModel.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"The Spine Model generator.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"A package to generate and run the Spine Model for energy system integration problems.","category":"page"},{"location":"#Package-features-1","page":"Home","title":"Package features","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Builds the model entirely from a database using Spine Model specific data structure.\nUses JuMP.jl to build and solve the optimization model.\nWrites results to the same input database or to a different one.\nThe model can be extended with additional constraints written in JuMP.\nSupports Julia 1.0.","category":"page"},{"location":"#Library-outline-1","page":"Home","title":"Library outline","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Pages = [\"library.md\"]\r\nDepth = 3","category":"page"},{"location":"library/#Library-1","page":"Library","title":"Library","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"Documentation for SpineModel.jl.","category":"page"},{"location":"library/#Contents-1","page":"Library","title":"Contents","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"Pages = [\"library.md\"]\r\nDepth = 3","category":"page"},{"location":"library/#Index-1","page":"Library","title":"Index","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"","category":"page"},{"location":"library/#Public-interface-1","page":"Library","title":"Public interface","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"run_spinemodel(::String, ::String)\r\nrun_spinemodel(::String)","category":"page"},{"location":"library/#SpineModel.run_spinemodel-Tuple{String,String}","page":"Library","title":"SpineModel.run_spinemodel","text":"run_spinemodel(url_in, url_out; <keyword arguments>)\n\nRun the Spine model from url_in and write report to url_out. At least url_in must point to valid Spine database. A new Spine database is created at url_out if it doesn't exist.\n\nKeyword arguments\n\nwith_optimizer=with_optimizer(Cbc.Optimizer, logLevel=0) is the optimizer factory for building the JuMP model.\n\ncleanup=true tells run_spinemodel whether or not convenience functors should be set to nothing after completion.\n\nadd_constraints=m -> nothing is called with the Model object in the first optimization window, and allows adding user contraints.\n\nupdate_constraints=m -> nothing is called in windows 2 to the last, and allows updating contraints added by add_constraints.\n\nlog_level=3 is the log level.\n\n\n\n\n\n","category":"method"},{"location":"library/#SpineModel.run_spinemodel-Tuple{String}","page":"Library","title":"SpineModel.run_spinemodel","text":"run_spinemodel(url; <keyword arguments>)\n\nRun the Spine model from url and write report to the same url. Keyword arguments have the same purpose as for run_spinemodel.\n\n\n\n\n\n","category":"method"},{"location":"library/#Internals-1","page":"Library","title":"Internals","text":"","category":"section"},{"location":"library/#Variables-1","page":"Library","title":"Variables","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"variable_flow\r\nvariable_trans\r\nvariable_units_on\r\nflow_indices\r\nvar_flow_indices\r\nfix_flow_indices\r\ntrans_indices\r\nvar_trans_indices\r\nfix_trans_indices\r\nunits_on_indices\r\nvar_units_on_indices\r\nfix_units_on_indices","category":"page"},{"location":"library/#SpineModel.flow_indices","page":"Library","title":"SpineModel.flow_indices","text":"flow_indices(\n    commodity=anything,\n    node=anything,\n    unit=anything,\n    direction=anything,\n    t=anything\n)\n\nA list of NamedTuples corresponding to indices of the flow variable. The keyword arguments act as filters for each dimension.\n\n\n\n\n\n","category":"function"},{"location":"library/#SpineModel.trans_indices","page":"Library","title":"SpineModel.trans_indices","text":"trans_indices(\n    commodity=anything,\n    node=anything,\n    connection=anything,\n    direction=anything,\n    t=anything\n)\n\nA list of NamedTuples corresponding to indices of the trans variable. The keyword arguments act as filters for each dimension.\n\n\n\n\n\n","category":"function"},{"location":"library/#SpineModel.units_on_indices","page":"Library","title":"SpineModel.units_on_indices","text":"units_on_indices(unit=anything, t=anything)\n\nA list of NamedTuples corresponding to indices of the units_on variable. The keyword arguments act as filters for each dimension.\n\n\n\n\n\n","category":"function"},{"location":"library/#Constraints-1","page":"Library","title":"Constraints","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"TODO","category":"page"},{"location":"library/#Objectives-1","page":"Library","title":"Objectives","text":"","category":"section"},{"location":"library/#","page":"Library","title":"Library","text":"TODO","category":"page"}]
}
