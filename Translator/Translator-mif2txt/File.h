#pragma once

#include "Core.h"

class File
{
public:
	File(const std::string InputFile, const std::string OutputFile);
	bool convert(int width, int depth) const;
private:
	std::string m_InputFile;
	std::string m_OutputFile;
};

