# Authored Wilds traversal fix

Authored Cypress Basin and Wet Woodland segments now own their main route composition completely. The procedural role-content pass no longer adds blocking rocks or ruin pillars on top of authored paths.

The authored segment smoke test verifies that both layouts instantiate with sockets and that no root-level procedural `Rock` or `RuinPillar` nodes are added.
