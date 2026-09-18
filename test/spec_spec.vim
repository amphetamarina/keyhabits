vim9script

# Specs for the spec DSL itself. Every It here must pass.

import './spec.vim' as spec

spec.Describe('spec', () => {
  spec.Describe('ToEqual', () => {
    spec.It('passes for equal lists and dicts', () => {
      spec.Expect([1, 2]).ToEqual([1, 2])
      spec.Expect({a: 1, b: [2]}).ToEqual({a: 1, b: [2]})
    })

    spec.It('reports a mismatch as an Expect: failure', () => {
      spec.Expect(() => spec.Expect(1).ToEqual(2)).ToThrow('^Expect:')
    })
  })

  spec.Describe('NotToEqual', () => {
    spec.It('passes for different values', () => {
      spec.Expect(1).NotToEqual(2)
      spec.Expect([1]).NotToEqual([2])
    })

    spec.It('reports equal values as a failure', () => {
      spec.Expect(() => spec.Expect('a').NotToEqual('a')).ToThrow('^Expect:')
    })
  })

  spec.Describe('ToBeTrue and ToBeFalse', () => {
    spec.It('passes for the matching boolean', () => {
      spec.Expect(true).ToBeTrue()
      spec.Expect(false).ToBeFalse()
    })

    spec.It('reports the opposite boolean as a failure', () => {
      spec.Expect(() => spec.Expect(false).ToBeTrue()).ToThrow('^Expect:')
      spec.Expect(() => spec.Expect(true).ToBeFalse()).ToThrow('^Expect:')
    })

    spec.It('accepts the numbers 1 and 0 as truth values', () => {
      spec.Expect(1).ToBeTrue()
      spec.Expect(0).ToBeFalse()
    })

    spec.It('reports the opposite number as a failure', () => {
      spec.Expect(() => spec.Expect(0).ToBeTrue()).ToThrow('^Expect:')
      spec.Expect(() => spec.Expect(1).ToBeFalse()).ToThrow('^Expect:')
    })

    spec.It('fails for a value that is neither a bool nor a number', () => {
      spec.Expect(() => spec.Expect('yes').ToBeTrue()).ToThrow('^Expect:')
      spec.Expect(() => spec.Expect('').ToBeFalse()).ToThrow('^Expect:')
    })
  })

  spec.Describe('ToContain', () => {
    spec.It('passes for a list element and for a string substring', () => {
      spec.Expect(['a', 'b']).ToContain('b')
      spec.Expect('keyhabits').ToContain('habits')
    })

    spec.It('reports a missing element or substring as a failure', () => {
      spec.Expect(() => spec.Expect(['a']).ToContain('b')).ToThrow('^Expect:')
      spec.Expect(() => spec.Expect('ab').ToContain('c')).ToThrow('^Expect:')
    })
  })

  spec.Describe('ToHaveLength', () => {
    spec.It('passes for the matching length', () => {
      spec.Expect([1, 2, 3]).ToHaveLength(3)
      spec.Expect('abc').ToHaveLength(3)
    })

    spec.It('reports a different length as a failure', () => {
      spec.Expect(() => spec.Expect([1]).ToHaveLength(2)).ToThrow('^Expect:')
    })
  })

  spec.Describe('ToThrow', () => {
    spec.It('passes when the func throws a matching message', () => {
      spec.Expect(() => {
        throw 'boom'
      }).ToThrow('^boom$')
    })

    spec.It('passes when the func throws a matching Vim error', () => {
      spec.Expect(() => {
        var Empty: list<number> = []
        return Empty[0]
      }).ToThrow('E684')
    })

    spec.It('reports a non-matching message as a failure', () => {
      spec.Expect(() => spec.Expect(() => {
        throw 'boom'
      }).ToThrow('nope')).ToThrow('^Expect:')
    })

    spec.It('reports a func that does not throw as a failure', () => {
      spec.Expect(() => spec.Expect(() => 1).ToThrow('boom')).ToThrow(
        'nothing was thrown')
    })
  })
})
