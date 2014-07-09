using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Logger
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
            WriteValue("Hello there I am boss");
        }

        private void WriteValue(string s)
        {
            var tabs = tabControl1;
            tabs.TabPages.Add("TabA");
            var page = tabs.TabPages[0];

            var tb = new RichTextBox();
            tb.Size = page.Size;
            tb.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Right | AnchorStyles.Left;           
            page.Controls.Add(tb);
            tb.AppendText(s);
        }
    }
}
