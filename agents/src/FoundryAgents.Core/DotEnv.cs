namespace FoundryAgents.Core;

internal static class DotEnv
{
    public static void LoadNearest()
    {
        foreach (string start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
        {
            DirectoryInfo? directory = new(start);
            while (directory is not null)
            {
                string path = Path.Combine(directory.FullName, ".env");
                if (File.Exists(path))
                {
                    Load(path);
                    return;
                }

                directory = directory.Parent;
            }
        }
    }

    private static void Load(string path)
    {
        foreach (System.Collections.DictionaryEntry variable in Environment.GetEnvironmentVariables())
        {
            if (variable.Key is string name
                && (name.StartsWith("AGENT_", StringComparison.Ordinal)
                    || name.StartsWith("FOUNDRY_", StringComparison.Ordinal)))
            {
                Environment.SetEnvironmentVariable(name, null);
            }
        }

        int lineNumber = 0;
        foreach (string rawLine in File.ReadLines(path))
        {
            lineNumber++;
            string line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith('#'))
            {
                continue;
            }

            int separator = line.IndexOf('=');
            if (separator <= 0)
            {
                throw new InvalidOperationException(
                    $"Invalid .env entry at line {lineNumber} in '{path}'.");
            }

            string name = line[..separator].Trim();
            string value = line[(separator + 1)..].Trim().Trim('"');
            Environment.SetEnvironmentVariable(name, value);
        }
    }
}
