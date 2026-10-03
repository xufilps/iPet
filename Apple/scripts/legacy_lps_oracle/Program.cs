// Synthetic compatibility fixtures only; never reads a user's save.
using System.Globalization;
using System.Text.Json;
using System.Text;
using System.Security.Cryptography;
using LinePutScript;
using LinePutScript.Converter;
CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
if (args.Contains("--statistics")) {
    // Mirrors Statistics.ToSubs and AddRange. No WPF, plugins or user files.
    var stats = new SortedDictionary<string,SetObject?> {
        ["stat_money"]=new SetObject(1234.5),["stat_buytimes"]=new SetObject(7),["stat_work_time"]=new SetObject(3600L),
        ["stat_bb_drink"]=new SetObject(1.25),["eval_day_20261003"]=new SetObject(600L),
        ["eval_longest_session_seconds"]=new SetObject(9007199254740993L),
        ["plugin_date"]=new SetObject(new DateTime(2026,10,3,12,34,56,DateTimeKind.Unspecified)),
        ["plugin_fixed"]=new SetObject(new FInt64(12.5)),["plugin_bool"]=new SetObject(true),
        ["plugin_text"]=new SetObject(Sub.TextReplace("主/n人\n:|#")),["skipped_null"]=null
    };
    var statsLine=new Line("statistics","",stats.Where(entry=>entry.Value!=null).Select(entry=>new Sub(entry.Key,entry.Value!)).ToList());
    var loadedStats = new SortedDictionary<string,SetObject?>();
    foreach(var sub in new Line(statsLine.ToString())) loadedStats.Add(sub.Name,sub.info);
    var entries=loadedStats.Select(entry=>new {key=entry.Key,stored=entry.Value!.GetString(),reads=StatisticsOracle.Read(entry.Value)}).ToArray();
    var coercions=new[] {"1.25","2147483648","bad","1,25","True","638950628960000000"}.Select(raw=>new {raw,reads=StatisticsOracle.Read(new SetObject(raw))}).ToArray();
    string duplicateOutcome;
    try { var duplicate=new SortedDictionary<string,SetObject?>();foreach(var sub in new Line("statistics:|same#1:|same#2:|")) duplicate.Add(sub.Name,sub.info);duplicateOutcome="accepted"; }
    catch(Exception ex) { duplicateOutcome=ex.GetType().Name; }
    CultureInfo.CurrentCulture=CultureInfo.GetCultureInfo("fr-FR");
    var foreign=new Sub("stat_bb_drink",new SetObject(1.25)).ToString();
    CultureInfo.CurrentCulture=CultureInfo.InvariantCulture;
    var foreignRead=new SetObject(new Line("statistics:|"+foreign).Find("stat_bb_drink")!.info).GetDouble();
    Console.WriteLine(JsonSerializer.Serialize(new {library="LinePutScript",version="1.11.9",upstream="1a06c598",culture="Invariant",input=statsLine.ToString(),entries,coercions,duplicateOutcome,foreignCulture="fr-FR",foreign,foreignRead},new JsonSerializerOptions {WriteIndented=true}));
    return;
}
if (args.Contains("--items")) {
    var itemCases = new LegacyItemDTO[] {
        new LegacyItemDTO {Name="测试道具",Image=null,Price=12.5,Count=3,Data="literal/null\n:|#",Desc="说明",Star=true,IsSingle=true,CanUse=false,Visibility=false},
        new LegacyFoodDTO {Name="测试食物",Image="/null",Price=21.75,Count=4,Data="冷却/n",Desc="原始说明",Star=true,Type=LegacyFoodType.Drink,Exp=7,Strength=-1.25,StrengthFood=3.5,StrengthDrink=9.75,Feeling=2.25,Health=-0.5,Likability=1.125,Graph=null}
    }.Select(value => {
        var line=LPSConvert.SerializeObjectToLine<Line>(value,"item0");
        LegacyItemDTO loaded=value is LegacyFoodDTO?LPSConvert.DeserializeObject<LegacyFoodDTO>(line):LPSConvert.DeserializeObject<LegacyItemDTO>(line);
        return new {kind=value.GetType().Name,input=line.ToString(),original=value.Snapshot(),loaded=loaded.Snapshot()};
    }).ToArray();
    var loads = new[] {"itemX:|name#x:|itemtype#Food:|price#2.5:|count#2:|type#Drink:|star#True:|", "itemX:|name#x:|itemtype#Food:|Price#2.5:|Count#2:|Type#Drink:|Star#True:|", "itemX:|name#x:|itemtype#Food:|Type#drink:|", "itemX:|name#x:|itemtype#Food:|Type#4:|", "itemX:|name#x:|itemtype#Food:|CanUse#0:|", "itemX:|name#x:|itemtype#Food:|Image#/null:|", "itemX:|name#x:|itemtype#Food:|Image#/!null:|"}
        .Select(input => { try { return new {input,outcome="accepted",loaded=(object?)LPSConvert.DeserializeObject<LegacyFoodDTO>(new Line(input)).Snapshot()}; } catch(Exception ex) { return new {input,outcome=ex.GetType().Name,loaded=(object?)null}; }}).ToArray();
    Console.WriteLine(JsonSerializer.Serialize(new {library="LinePutScript",version="1.11.9",upstream="1a06c598",culture="Invariant",cases=itemCases,loads},new JsonSerializerOptions {WriteIndented=true}));
    return;
}
if (args.Contains("--hashes")) {
    var serializations = new[] {"", ":|f#one:|text///note", "alone\nplain#info\nempty:|", "vpet#head/!n:|note#/n/id:|tail///comment", "vpet:|name#first:\r\n|second:|\r\nstatistics:|day#1:\n:2:|"}
        .Select(input => new {input,canonical=new LpsDocument(input).ToString()}).ToArray();
    var hashCases = new[] {HashOracle.Build("rootSHA512",2),HashOracle.Build("rootMD5",0),HashOracle.Build("rootSHA512",1),HashOracle.Build("legacyPetMD5",2)};
    Console.WriteLine(JsonSerializer.Serialize(new {library="LinePutScript",version="1.11.9",upstream="1a06c598",serializations,cases=hashCases},new JsonSerializerOptions {WriteIndented=true}));
    return;
}
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

public static class HashOracle {
    public static long MD5Prefix(string text) => BitConverter.ToInt64(MD5.HashData(Encoding.UTF8.GetBytes(text)),0);
    public static object Build(string path,int version) {
        var document = new LpsDocument(LPSConvert.SerializeObject(new PetFieldsDTO(),"vpet").ToString()+"\r\nstatistics:|stat_total_time#30:|///stats\r\nplugin:|text#literal/!n/n/id/com:|body///external");
        var canonical = document.ToString();
        long expected;
        if (path=="legacyPetMD5") {
            var pet=document.FindLine("vpet")!;
            pet.Add(new Sub("note","literal/n\n#"));
            unchecked {
                expected=MD5Prefix(pet.Name)*2+MD5Prefix(((ISub)pet).info)*3+MD5Prefix(pet.text)*4;
                foreach (var field in pet) expected+=MD5Prefix(field.Name)*2+MD5Prefix(field.Info)*3;
            }
            canonical=document.ToString();
            pet.Add(new Sub("hash",expected.ToString()));
            // The original pet route has priority even when another root hash exists.
            document.AddLine(new Line("hash","123","",new Sub("ver","99")));
        } else {
            expected=path=="rootMD5"?MD5Prefix(canonical):Sub.GetHashCode(canonical);
            document.AddLine(new Line("hash",expected.ToString(),"",new Sub("ver",version.ToString())));
        }
        return new {path,scope=path=="legacyPetMD5"?"pet":"document",version,input=document.ToString(),canonical,expected=expected.ToString()};
    }
}

// Serialization DTOs preserve upstream property inheritance and annotations.
// They intentionally omit WPF/UI methods; no plugin or user data is loaded.
public class LegacyItemDTO {
    [Line(ignoreCase:true)] public virtual string? Image {get;set;} = null;
    [Line(name:"name")] public string Name {get;set;} = "";
    [Line(name:"itemtype")] public virtual string ItemType {get;set;} = "Item";
    [Line(ignoreCase:true)] public virtual double Price {get;set;}
    [Line(ignoreCase:true)] public string Desc {get;set;} = "";
    [Line(ignoreCase:true)] public virtual int Count {get;set;} = 1;
    [Line(ignoreCase:true)] public virtual string Data {get;set;} = "";
    [Line(ignoreCase:true)] public virtual bool CanUse {get;set;} = true;
    [Line(ignoreCase:true)] public virtual bool Star {get;set;}
    [Line(ignoreCase:true)] public virtual bool IsSingle {get;set;}
    [Line(ignoreCase:true)] public virtual bool Visibility {get;set;} = true;
    public virtual object Snapshot() => new {Image,Name,ItemType,Price,Desc,Count,Data,CanUse,Star,IsSingle,Visibility};
}
public enum LegacyFoodType {Food,Star,Meal,Snack,Drink,Functional,Drug,Gift}
public class LegacyFoodDTO : LegacyItemDTO {
    public override string ItemType => "Food";
    public override bool Star {get;set;}
    [Line(type:LPSConvert.ConvertType.ToEnum,ignoreCase:true)] public LegacyFoodType Type {get;set;}
    [Line(ignoreCase:true)] public int Exp {get;set;}
    [Line(ignoreCase:true)] public double Strength {get;set;}
    [Line(ignoreCase:true)] public double StrengthFood {get;set;}
    [Line(ignoreCase:true)] public double StrengthDrink {get;set;}
    [Line(ignoreCase:true)] public double Feeling {get;set;}
    [Line(ignoreCase:true)] public double Health {get;set;}
    [Line(ignoreCase:true)] public double Likability {get;set;}
    [Line(ignoreCase:true)] public string? Graph {get;set;}
    public override object Snapshot() => new {Image,Name,ItemType,Price,Desc,Count,Data,CanUse,Star,IsSingle,Visibility,Type=Type.ToString(),Exp,Strength,StrengthFood,StrengthDrink,Feeling,Health,Likability,Graph};
}

public static class StatisticsOracle {
    private static string Probe(Func<string> get) { try { return get(); } catch(Exception ex) { return "error:"+ex.GetType().Name; } }
    public static object Read(SetObject value) => new {
        int32=Probe(()=>value.GetInteger().ToString(CultureInfo.InvariantCulture)),
        int64=Probe(()=>value.GetInteger64().ToString(CultureInfo.InvariantCulture)),
        ordinaryDouble=Probe(()=>value.GetDouble().ToString("R",CultureInfo.InvariantCulture)),
        fixedStored=Probe(()=>value.GetFloat().ToStoreString()),
        dateTicks=Probe(()=>value.GetDateTime().Ticks.ToString(CultureInfo.InvariantCulture)),
        boolean=Probe(()=>value.GetBoolean().ToString()),text=Probe(()=>value.GetString())
    };
}
