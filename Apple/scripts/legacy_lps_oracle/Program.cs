// Synthetic compatibility fixtures only; never reads a user's save.
using System.Globalization;
using System.Text.Json;
using LinePutScript;
using LinePutScript.Converter;
CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
if (args.Contains("--pet-fields")) {
    var pet = new PetFieldsDTO();
    var line = LPSConvert.SerializeObject(pet, "vpet");
    var loaded = LPSConvert.DeserializeObject<PetFieldsDTO>(new Line(line.ToString()))!;
    string unknownModeOutcome;
    try { LPSConvert.DeserializeObject<PetFieldsDTO>(new Line(line.ToString().Replace("mode#Happy", "mode#Bogus"))); unknownModeOutcome="accepted"; }
    catch (Exception exception) { unknownModeOutcome=exception.GetType().Name; }
    Console.WriteLine(JsonSerializer.Serialize(new {library="LinePutScript",version="1.11.9",upstream="1a06c598",input=line.ToString(),expected=loaded.Snapshot(),unknownModeOutcome},new JsonSerializerOptions {WriteIndented=true}));
    return;
}
var texts = new[] {
    "vpet:|Level#10:|LevelMax#0:|money#100000000000:|exp#50000000000:|",
    "vpet#id:|name#萝莉斯:|name#第二名:|Name#大小写:|末尾///comment///tail",
    "vpet:|hostname#" + Sub.TextReplace("主/n人\n:|#,/|=\t\r") + ":|" + Sub.TextReplace("文本/n\n:|#,/|="),
    "vpet:|name#first:\r\n|second:|\r\n\r\nstatistics:|day#1:\n:2:|",
    "alone\nplain#info\nempty:|\ncomment///note\n",
    "vpet:|value#one#two:|value:|last",
    "vpet:|Level#10:|\nvpet:|Level#20:|",
    "vpet#\u0301header:|name#\u0301x:|",
    "vpet:|e\u0301#first:|é#second:|"
};
var cases = texts.Select(input => {
    var document = new LpsDocument(input);
    return new { input, lines = document.Select(line => new {
        name = line.Name, rawInfo = ((ISub)line).info, info = line.Info,
        rawText = line.text, text = line.Text, comment = line.Comments,
        fields = line.Select(field => new {name = field.Name, rawInfo = field.info, info = field.Info}).ToArray(),
        lookups = new[] {"name", "Name", "NAME", "é", "e\u0301"}.Select(name => new { name, info = line.Find(name)?.Info }).ToArray()
    }).ToArray() };
}).ToArray();
var numbers = new[] {0.0, 1.0, -1.0, 100.0, 50.25, -0.000000001, 1234.56789, 199899.95}.Select(value => {
    var number = new FInt64(value); var stored = number.ToStoreString();
    return new {value, stored, decoded = FInt64.Parse(stored).ToDouble()};
}).ToArray();
var sentinels = new[] {long.MinValue, long.MinValue+1, long.MaxValue-1, long.MaxValue}.Select(raw => {
    var number = FInt64.Parse(raw.ToString());
    return new {raw=raw.ToString(), nan=number.IsNaN(), negativeInfinity=number.IsNegativeInfinity(), positiveInfinity=number.IsPositiveInfinity(), decoded=number.IsNaN()?"NaN":number.ToDouble().ToString("R")};
}).ToArray();
Console.WriteLine(JsonSerializer.Serialize(new {library="LinePutScript",version="1.11.9",sourceCommit="69ea42f7f213be2669879705035a77a1804c457a",culture="Invariant",cases,numbers,sentinels}, new JsonSerializerOptions {WriteIndented=true}));

// Serialization-only DTO mirrors annotated field names/types of GameSave_VPet.
// It does not emulate its growth setter; PetDesktopGrowth tests cover that separately.
public class PetFieldsDTO {
    [Line(name:"name")] public string Name {get;set;} = "萝莉斯";
    [Line(name:"hostname")] public string HostName {get;set;} = "阿轩🐱";
    [Line(Type=LPSConvert.ConvertType.ToFloat,Name="money")] public double Money {get;set;} = 1234.5;
    [Line] public int Level {get;set;} = 10;
    [Line] public int LevelMax {get;set;} = 0;
    [Line(type:LPSConvert.ConvertType.ToFloat,name:"exp")] public double Exp {get;set;} = 50;
    [Line(Type=LPSConvert.ConvertType.ToFloat,IgnoreCase=true)] protected double strength {get;set;} = 115.5;
    [Line(Type=LPSConvert.ConvertType.ToFloat,IgnoreCase=true)] public double StoreStrength {get;set;} = -1.25;
    [Line(Type=LPSConvert.ConvertType.ToFloat)] protected double strengthFood {get;set;} = 90.25;
    [Line(Type=LPSConvert.ConvertType.ToFloat)] public double StoreStrengthFood {get;set;} = 2.75;
    [Line(Type=LPSConvert.ConvertType.ToFloat)] protected double strengthDrink {get;set;} = 85.5;
    [Line(Type=LPSConvert.ConvertType.ToFloat)] public double StoreStrengthDrink {get;set;} = 1;
    [Line(Type=LPSConvert.ConvertType.ToFloat)] protected double feeling {get;set;} = 105.5;
    [Line(Type=LPSConvert.ConvertType.ToFloat)] protected double health {get;set;} = 82;
    [Line(Type=LPSConvert.ConvertType.ToFloat)] protected double likability {get;set;} = 135.25;
    [Line(name:"mode")] public FixtureMood Mode {get;set;} = FixtureMood.Happy;
    [Line] public double LikabilityMax {get;set;} = 150.25;
    public object Snapshot() => new {name=Name,hostName=HostName,money=Money,level=Level,prestige=LevelMax,experience=Exp,strength,food=strengthFood,drink=strengthDrink,feeling,health,affection=likability,affectionMax=LikabilityMax,storedStrength=StoreStrength,storedFood=StoreStrengthFood,storedDrink=StoreStrengthDrink,savedMode=Mode.ToString()};
}

public enum FixtureMood { Happy, Nomal, PoorCondition, Ill }
