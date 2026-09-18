vim9script

# The port the recorder and the reporter depend on: where events are kept.
# Adapters live in infra/ and are wired in at the composition root.

export interface EventStore
  def Append(events: list<dict<any>>)
  def ReadAll(): list<dict<any>>
  def Clear()
endinterface
