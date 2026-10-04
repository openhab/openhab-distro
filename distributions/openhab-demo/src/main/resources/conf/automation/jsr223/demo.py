scriptExtension.importPreset("RuleSupport")
scriptExtension.importPreset("RuleSimple")

class MyRule(SimpleRule):
    def __init__(self):
        self.triggers = [
            TriggerBuilder.create()
                    .withId("aTimerTrigger")
                    .withTypeUID("timer.GenericCronTrigger")
                    .withConfiguration(
                        Configuration({
                            "cronExpression": "0 * * * * ?"
                        })).build()
        ]

    def execute(self, module, inputs):
        print "This is a 'hello world!' from Jython rule."

automationManager.addRule(MyRule())
