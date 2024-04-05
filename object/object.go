package object

import "fmt"

type Object interface {
	Type() ObjectType
	Inspect() string
}

type ObjectType string

const (
	NULL         = "NULL"
	BOOLEAN      = "BOOLEAN"
	INTEGER      = "INTEGER"
	RETURN_VALUE = "RETURN_VALUE"
	ERROR        = "ERROR"
)

type Null struct{}

func (n *Null) Type() ObjectType { return NULL }
func (n *Null) Inspect() string  { return "null" }

type Boolean struct {
	Value bool
}

func (b *Boolean) Type() ObjectType { return BOOLEAN }
func (b *Boolean) Inspect() string  { return fmt.Sprintf("%t", b.Value) }

type Integer struct {
	Value int64
}

func (i *Integer) Type() ObjectType { return INTEGER }
func (i *Integer) Inspect() string  { return fmt.Sprintf("%d", i.Value) }

type ReturnValue struct {
	Value Object
}

func (rv *ReturnValue) Type() ObjectType { return RETURN_VALUE }
func (rv *ReturnValue) Inspect() string  { return rv.Value.Inspect() }

type Error struct {
	Message string
}

func (e *Error) Type() ObjectType { return ERROR }
func (e *Error) Inspect() string  { return e.Message }
