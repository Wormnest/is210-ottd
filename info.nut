class rocketAI extends AIInfo {
  function GetAuthor()      { return "Team Rocket"; }
  function GetName()        { return "rocketAI"; }
  function GetDescription() { return "En AI basert på http://wiki.openttd.org/"; }
  function GetVersion()     { return 1; }
  function GetDate()        { return "2009-11-26"; }
  function CreateInstance() { return "rocketAI"; }
  function GetShortName()   { return "trAI"; }
}
/* Tell the core we are an AI */
RegisterAI(rocketAI());
