Meshnodes for Minetest [meshnode]
=================================

Meshnodes is a mod that transforms ordinary nodes into a connected
array of replica entities to which players can attach to and manoeuvre.

To use, simply build or place a model using nodes with a supported drawtype.
Next place a meshnode controller in the appropriate position, the operator
will be attached directly on top of the controller node.

Now right click the controller and enter the minimum and maximum extents of
the model (relative to the controller x,y,z)

e.g. for a 3x3 square of nodes with the controller placed above the center
node, the relative positions would be minp = -1,-1,-1 maxp = 1,0,1

Alternatively, if you are using worldedit, you can use the position
markers to define the extents of the model. However, this must be done
before the controller is placed.

Supported Drawtypes
===================

normal
allfaces_optional
glasslike
plantlike
fencelike

Also supports all default stairs and slabs in full 6d rotation.

Controls
========

[Up]	Forward
[Down]	Reverse
[Left]	Rotate Left
[Right]	Rotate Right
[Jump]	Up
[Sneak]	Down
[RMB]	Attach/Detach

Know Issues
===========

The player controlling the entity may appear to be connected to the wrong
part of the model when viewed by a player that was not present during the
initial attachment. Currently the only solution is for the operator to
detach then re-attach to the model in the presence of said player.

