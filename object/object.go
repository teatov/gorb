package object

import "fmt"

type Object interface {
	Type() ObjectType
	Inspect() string
}

type ObjectType string

const (
	BOOLEAN = "BOOLEAN"
	INTEGER = "INTEGER"
	NULL    = "NULL"
)

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

type Null struct{}

func (n *Null) Type() ObjectType { return NULL }
func (n *Null) Inspect() string  { return "null" }
