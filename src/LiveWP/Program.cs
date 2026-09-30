using System;
using System.Windows.Forms;

namespace LiveWP;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.SetCompatibleTextRenderingDefault(false);

        var form = new MainForm();
        Application.Run(form);
    }
}
