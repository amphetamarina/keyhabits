vim9script

# The port the coach depends on: how a tip reaches the user. Adapters live in
# infra/ and are wired in at the composition root.

export interface Notifier
  def Notify(rule: dict<any>)
endinterface
