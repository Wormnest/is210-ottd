class rocketAI extends AIController 
{
  function Start();
}

function rocketAI::Start()
{
	if (!AICompany.SetName("Team Rocket AI")) {
    local i = 2;
    while (!AICompany.SetName("Team Rocket AI" + i)) {
      i = i + 1;
    }
  }

  while (true) {
    AILog.Info("I am a very new AI with a ticker called MyNewAI and I am at tick " + this.GetTick());
    this.Sleep(50);
  }
  
}
