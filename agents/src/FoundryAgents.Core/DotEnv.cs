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
        foreach (string rawLine in File.ReadLines(path))
        {
            string line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith('#'))
            {
                continue;
            }

            int separator = line.IndexOf('=');
            if (separator <= 0)
            {
                throw new InvalidOperationException($"Invalid .env entry in '{path}': {rawLine}");
            }

            string name = line[..separator].Trim();
            string value = line[(separator + 1)..].Trim().Trim('"');
            if (Environment.GetEnvironmentVariable(name) is null)
            {
                Environment.SetEnvironmentVariable(name, value);
            }
        }
    }
}
