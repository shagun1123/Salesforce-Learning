// File: ContactChangeTrigger.trigger
trigger ContactChangeTrigger on ContactChangeEvent (after insert) {
    CDCEventHandler.handle(Trigger.new, 'Contact');
}