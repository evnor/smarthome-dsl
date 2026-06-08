# Classes

## Connections
 - Connections between multiple device's ports

## Device
 - Ports
 - States
 - Transitions

## Port
 - type (http/xml, http/json, i2c(pins), raw pin, mqtt...)
 - schema (schema, i.e. number, string, lists, dictionary, etc...)

## Schema
// json or xml schema, look at that

## State
 - Name
 - Asssociated data

## Transistions
 - Source state
 - Target state
 - Actions?
    - Programming language for actions
 - Condition?

# Python
 - For each device, code which creates a webserver according to the state machine

# Papers
## General DSL Engineering
 - https://dl.acm.org/doi/abs/10.1145/1118890.1118892
 - https://arxiv.org/abs/1409.2378
## Domain specific
 - Inspired by: https://www.ketzu.net/wp-content/uploads/mde4iotpaper1.pdf
 - https://www.scitepress.org/PublishedPapers/2017/62854/pdf/index.html