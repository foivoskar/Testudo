\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{testudomanual}[2026/10/03 Testudo User Manual Class]

\LoadClass[11pt,a4paper,oneside]{report}

% ------------------------------------------------------------
% Encoding and typography
% ------------------------------------------------------------

\RequirePackage[T1]{fontenc}
\RequirePackage[utf8]{inputenc}
\RequirePackage{lmodern}
\RequirePackage{microtype}
\RequirePackage{setspace}
\RequirePackage{parskip}

% ------------------------------------------------------------
% Page geometry
% ------------------------------------------------------------

\RequirePackage[
    a4paper,
    top=24mm,
    bottom=26mm,
    inner=24mm,
    outer=24mm,
    headheight=15pt
]{geometry}

% ------------------------------------------------------------
% Core packages
% ------------------------------------------------------------

\RequirePackage{graphicx}
\RequirePackage{xcolor}
\RequirePackage{array}
\RequirePackage{booktabs}
\RequirePackage{tabularx}
\RequirePackage{longtable}
\RequirePackage{enumitem}
\RequirePackage{listings}
\RequirePackage{xurl}
\RequirePackage{fancyhdr}
\RequirePackage{titlesec}
\RequirePackage{hyperref}
\RequirePackage{caption}

% ------------------------------------------------------------
% Testudo colours
% ------------------------------------------------------------

\definecolor{TestudoBlue}{HTML}{27689B}
\definecolor{TestudoDarkBlue}{HTML}{173B57}
\definecolor{TestudoLightBlue}{HTML}{EAF3F9}
\definecolor{TestudoVeryLightBlue}{HTML}{F5F9FC}
\definecolor{TestudoGray}{HTML}{60656A}
\definecolor{TestudoLightGray}{HTML}{EEF0F2}
\definecolor{TestudoDarkGray}{HTML}{282C30}
\definecolor{TestudoGreen}{HTML}{347A45}
\definecolor{TestudoOrange}{HTML}{B56A16}
\definecolor{TestudoRed}{HTML}{A43838}

% ------------------------------------------------------------
% Hyperlinks
% ------------------------------------------------------------

\hypersetup{
    colorlinks=true,
    linkcolor=TestudoDarkBlue,
    urlcolor=TestudoBlue,
    citecolor=TestudoDarkBlue,
    pdfborder={0 0 0},
    bookmarksopen=true,
    bookmarksnumbered=true
}

% ------------------------------------------------------------
% General typography
% ------------------------------------------------------------

\setstretch{1.05}

\setlength{\parindent}{0pt}
\setlength{\parskip}{5.5pt}

\setlist[itemize]{
    leftmargin=1.7em,
    itemsep=2pt,
    topsep=4pt
}

\setlist[enumerate]{
    leftmargin=1.9em,
    itemsep=3pt,
    topsep=4pt
}

\renewcommand{\arraystretch}{1.25}

% ------------------------------------------------------------
% Chapter and section formatting
% ------------------------------------------------------------

\titleformat{\chapter}[display]
    {\normalfont\bfseries\color{TestudoDarkBlue}}
    {\Large\chaptername\ \thechapter}
    {5pt}
    {\Huge}

\titlespacing*{\chapter}
    {0pt}
    {-12pt}
    {22pt}

\titleformat{\section}
    {\Large\bfseries\color{TestudoDarkBlue}}
    {\thesection}
    {0.65em}
    {}

\titleformat{\subsection}
    {\large\bfseries\color{TestudoBlue}}
    {\thesubsection}
    {0.6em}
    {}

\titleformat{\subsubsection}
    {\normalsize\bfseries\color{TestudoDarkGray}}
    {\thesubsubsection}
    {0.5em}
    {}

% ------------------------------------------------------------
% Header and footer
% ------------------------------------------------------------

\pagestyle{fancy}
\fancyhf{}

\fancyhead[L]{
    \small\color{TestudoGray}Testudo User Manual
}

\fancyhead[R]{
    \small\color{TestudoGray}\nouppercase{\leftmark}
}

\fancyfoot[C]{
    \small\color{TestudoGray}\thepage
}

\renewcommand{\headrulewidth}{0.3pt}
\renewcommand{\footrulewidth}{0pt}

\fancypagestyle{plain}{
    \fancyhf{}
    \fancyfoot[C]{
        \small\color{TestudoGray}\thepage
    }
    \renewcommand{\headrulewidth}{0pt}
}

% ------------------------------------------------------------
% Code listings
% ------------------------------------------------------------

\lstdefinestyle{TestudoTerminal}{
    basicstyle=\ttfamily\small,
    backgroundcolor=\color{TestudoVeryLightBlue},
    frame=single,
    rulecolor=\color{TestudoLightGray},
    framerule=0.5pt,
    xleftmargin=0.4em,
    xrightmargin=0.4em,
    framexleftmargin=0.5em,
    framexrightmargin=0.5em,
    aboveskip=8pt,
    belowskip=8pt,
    breaklines=true,
    breakatwhitespace=false,
    columns=fullflexible,
    keepspaces=true,
    showstringspaces=false
}

\lstset{
    style=TestudoTerminal
}

% ------------------------------------------------------------
% Useful manual environments
% ------------------------------------------------------------

\newcommand{\manualnote}[2]{
    \par
    \vspace{5pt}
    \noindent
    \fcolorbox{TestudoBlue}{TestudoLightBlue}{
        \parbox{\dimexpr\linewidth-2\fboxsep-2\fboxrule}{
            \textbf{\color{TestudoDarkBlue}#1}\par
            \smallskip
            #2
        }
    }
    \par
    \vspace{5pt}
}

\newcommand{\manualwarning}[2]{
    \par
    \vspace{5pt}
    \noindent
    \fcolorbox{TestudoOrange}{white}{
        \parbox{\dimexpr\linewidth-2\fboxsep-2\fboxrule}{
            \textbf{\color{TestudoOrange}#1}\par
            \smallskip
            #2
        }
    }
    \par
    \vspace{5pt}
}

\newcommand{\manualtip}[2]{
    \par
    \vspace{5pt}
    \noindent
    \fcolorbox{TestudoGreen}{white}{
        \parbox{\dimexpr\linewidth-2\fboxsep-2\fboxrule}{
            \textbf{\color{TestudoGreen}#1}\par
            \smallskip
            #2
        }
    }
    \par
    \vspace{5pt}
}

% ------------------------------------------------------------
% Semantic formatting
% ------------------------------------------------------------

\newcommand{\menu}[1]{\textbf{#1}}
\newcommand{\button}[1]{\textbf{#1}}
\newcommand{\fileext}[1]{\texttt{#1}}
\newcommand{\filepath}[1]{\texttt{#1}}
\newcommand{\term}[1]{\textbf{#1}}

\newcommand{\Testudo}{\textbf{Testudo}}

% ------------------------------------------------------------
% Table helpers
% ------------------------------------------------------------

\newcolumntype{Y}{
    >{\raggedright\arraybackslash}X
}

\newcolumntype{L}[1]{
    >{\raggedright\arraybackslash}p{#1}
}

% ------------------------------------------------------------
% Miscellaneous
% ------------------------------------------------------------

\setcounter{tocdepth}{2}
\setcounter{secnumdepth}{3}

\captionsetup{
    font=small,
    labelfont=bf
}

\endinput
