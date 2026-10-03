// Synthetic compatibility fixtures only; never reads a user's save.
using System.Globalization;
using System.Text.Json;
using LinePutScript;
CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
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
