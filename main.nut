class rocketAI extends AIController 
{
  function Start();
}

function rocketAI::Start()
{
  while (true) {
    AILog.Info("I am a very new AI with a ticker called MyNewAI and I am at tick " + this.GetTick());
    this.Sleep(50);
  }
}
