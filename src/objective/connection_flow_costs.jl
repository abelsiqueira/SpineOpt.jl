#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of Spine Model.
#
# Spine Model is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Spine Model is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

"""
    connection_flow_costs(m::Model)
"""
function connection_flow_costs(m::Model,t1)
    @fetch connection_flow = m.ext[:variables]
    a = @expression(
        m,
        reduce(
            +,
            connection_flow[conn, n, d, s, t]* duration(t) * connection_flow_cost[(connection=conn,t=t)]
            for conn in indices(connection_flow_cost)
                for (conn, n, d, s, t) in connection_flow_indices(connection=conn)
                    if end_(t) <= t1; #TODO: do we need connection_flow_costs in different directions?
            init=0
        )
    )
    # @show typeof(a)
    # @show drop_zeros!(a)
    # @show a
    a
end
#TODO: add weight scenario tree
