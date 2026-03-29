extends Node

# Shared code to break circular dependencies

enum _GenerationType {
    BODY,
    NUDE,
    NUDE_FROM_BODY,
    PREGNANT,
    PREGNANT_FROM_BODY,
    NUDE_PREGNANT,
    NUDE_PREGNANT_FROM_NUDE,
    PORTRAIT_FROM_BODY,
    PORTRAIT_FROM_NUDE
}

var GenerationType = _GenerationType
