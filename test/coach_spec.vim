vim9script

# Specs for the Coach use case, with a notifier that only remembers what it
# was asked to show.

import './spec.vim' as spec
import autoload 'keyhabits/app/coach.vim'
import autoload 'keyhabits/app/notifier.vim'
import autoload 'keyhabits/domain/advice.vim'

class FakeNotifier implements notifier.Notifier
  var shown: list<string> = []

  def Notify(rule: dict<any>)
    add(this.shown, rule.id)
  enddef
endclass

# threshold 2, window 60 seconds, cooldown 600 seconds
def NewCoach(fake: FakeNotifier): coach.Coach
  return coach.Coach.new(fake, advice.Rules(), 2, 60, 600)
enddef

# Feeds the commands one per second starting at start.
def Feed(subject: coach.Coach, commands: list<string>, start: number)
  var now: number = start
  for command in commands
    subject.Observe(command, now)
    now += 1
  endfor
enddef

const two_runs: list<string> = ['j', 'j', 'j', 'j', 'w', 'j', 'j', 'j', 'j']

spec.Describe('coach.Coach', () => {
  spec.It('stays quiet while a rule has not reached the threshold', () => {
    var fake: FakeNotifier = FakeNotifier.new()
    Feed(NewCoach(fake), ['j', 'j', 'j', 'j', 'w'], 1000)
    spec.Expect(fake.shown).ToEqual([])
  })

  spec.It('shows the tip once the rule reaches the threshold', () => {
    var fake: FakeNotifier = FakeNotifier.new()
    Feed(NewCoach(fake), two_runs, 1000)
    spec.Expect(fake.shown).ToEqual(['repeated-j'])
  })

  spec.It('does not repeat a tip during its cooldown', () => {
    var fake: FakeNotifier = FakeNotifier.new()
    var subject: coach.Coach = NewCoach(fake)
    Feed(subject, two_runs, 1000)
    Feed(subject, two_runs, 1100)
    spec.Expect(fake.shown).ToEqual(['repeated-j'])
  })

  spec.It('shows the tip again after the cooldown', () => {
    var fake: FakeNotifier = FakeNotifier.new()
    var subject: coach.Coach = NewCoach(fake)
    Feed(subject, two_runs, 1000)
    Feed(subject, two_runs, 1700)
    spec.Expect(fake.shown).ToEqual(['repeated-j', 'repeated-j'])
  })

  spec.It('forgets commands older than the window', () => {
    var fake: FakeNotifier = FakeNotifier.new()
    var subject: coach.Coach = NewCoach(fake)
    Feed(subject, ['j', 'j', 'j', 'j', 'w'], 1000)
    Feed(subject, ['j', 'j', 'j', 'j', 'w'], 1100)
    spec.Expect(fake.shown).ToEqual([])
  })

  spec.It('keeps cooling one rule while another one is shown', () => {
    var fake: FakeNotifier = FakeNotifier.new()
    var subject: coach.Coach = NewCoach(fake)
    Feed(subject, two_runs, 1000)
    Feed(subject, ['d$', 'w', 'd$'], 1010)
    spec.Expect(fake.shown).ToEqual(['repeated-j', 'delete-to-end'])
  })
})
